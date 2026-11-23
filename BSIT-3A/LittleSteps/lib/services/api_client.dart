import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_cache.dart';

// Base exception thrown when an HTTP or API request fails.
class ApiException implements Exception {
  // Creates an [ApiException] with status code, error code, message and details.
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const [],
  });

  // HTTP status code returned by the server.
  final int statusCode;

  // Error code identifying the failure reason.
  final String code;

  // Human-readable error description.
  final String message;

  // Additional error detail objects.
  final List<Map<String, dynamic>> details;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}

// Exception thrown when an HTTP request exceeds its allowed timeout duration.
class TimeoutApiException extends ApiException {
  // Creates a [TimeoutApiException] with default timeout code and message.
  TimeoutApiException({
    super.message = 'The request timed out. Please try again.',
  }) : super(statusCode: 408, code: 'TIMEOUT');
}

// Exception thrown when a socket failure or loss of network connectivity occurs.
class NoConnectionApiException extends ApiException {
  // Creates a [NoConnectionApiException] representing offline or unreachable network.
  NoConnectionApiException({
    super.message = 'No network connection. Working offline.',
  }) : super(statusCode: 0, code: 'NO_CONNECTION');
}

// Exception thrown when an API request fails authentication or permission checks (401/403).
class AuthApiException extends ApiException {
  // Creates an [AuthApiException] with status 401 or 403.
  AuthApiException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.details,
  });
}

// Exception thrown when an endpoint or resource returns HTTP 404 Not Found.
class NotFoundApiException extends ApiException {
  // Creates a [NotFoundApiException] for missing catalog items or endpoints.
  NotFoundApiException({
    required super.code,
    required super.message,
    super.details,
  }) : super(statusCode: 404);
}

// Exception thrown when the backend server fails with a 5xx status code.
class ServerApiException extends ApiException {
  // Creates a [ServerApiException] for backend internal errors.
  ServerApiException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.details,
  });
}

// Exception thrown when write operations are attempted while offline without queueing.
class OfflineWriteApiException extends NoConnectionApiException {
  // Creates an [OfflineWriteApiException] enforcing the required offline write rejection copy.
  OfflineWriteApiException({super.message = 'Reconnect to save changes'});
}

// HTTP client for interacting with the backend API with offline caching and connectivity resilience.
class ApiClient {
  // Creates an [ApiClient] with optional authentication hooks, local cache, and client injection.
  ApiClient({
    String? baseUrl,
    String? host,
    http.Client? httpClient,
    this.tokenProvider,
    this.onRefreshToken,
    this.onSessionExpired,
    LocalDataCache? cache,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client(),
       baseUrl = baseUrl ?? defaultBaseUrl(host: host),
       cache = cache ?? LocalDataCache();

  final http.Client _httpClient;

  // Base URL endpoint for all API requests.
  final String baseUrl;

  // Local offline cache storing whitelisted read datasets.
  final LocalDataCache cache;

  // Request timeout duration for network operations.
  final Duration requestTimeout;

  String? _authToken;
  bool _isOffline = false;

  // Listenable notifier alerting UI subscribers when offline status changes.
  final ValueNotifier<bool> isOfflineNotifier = ValueNotifier<bool>(false);

  // Optional provider function returning the active authentication token.
  final String? Function()? tokenProvider;

  // Optional callback invoked when a request returns 401 to refresh the token.
  final Future<String?> Function()? onRefreshToken;

  // Optional callback invoked when a session has unrecoverably expired.
  final VoidCallback? onSessionExpired;

  // Current active authorization token.
  String? get authToken => tokenProvider?.call() ?? _authToken;

  // Whether the client is currently in offline mode.
  bool get isOffline => _isOffline;

  // Manually sets the offline mode flag and notifies listeners.
  set isOffline(bool value) {
    if (_isOffline != value) {
      _isOffline = value;
      isOfflineNotifier.value = value;
    }
  }

  // Sets the bearer token for authenticated requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Clears the local offline data cache (e.g., during sign out or session expiration).
  void clearCache() {
    cache.clear();
  }

  // Returns the default host based on runtime platform (10.0.2.2 for Android emulator).
  static String get defaultHost {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }

  // Computes default base URL with an optional configurable [host].
  static String defaultBaseUrl({String? host}) {
    final selectedHost = host ?? defaultHost;
    return 'http://$selectedHost:5001/demo-littlesteps/asia-southeast1/api';
  }

  // Determines whether an endpoint [path] is protected by authentication.
  static bool isProtectedPath(String path) {
    if (path.contains('/catalog/activities') ||
        path.contains('/catalog/weather') ||
        path.contains('/health')) {
      return false;
    }
    return true;
  }

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Future<http.Response> _sendWithRetry(
    String path,
    Future<http.Response> Function(Map<String, String> headers) sendRequest,
  ) async {
    var response = await sendRequest(_headers());

    if (response.statusCode == 401 && isProtectedPath(path)) {
      final newToken = await onRefreshToken?.call();
      if (newToken != null && newToken.isNotEmpty) {
        setAuthToken(newToken);
        response = await sendRequest(_headers());
      }
      if (response.statusCode == 401) {
        onSessionExpired?.call();
      }
    }

    return response;
  }

  // Sends a GET request and transparently returns cached data when offline.
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final cacheKey = cache.generateKey(path, queryParams);

    if (_isOffline) {
      if (cache.isCacheablePath(path) && cache.has(cacheKey)) {
        return cache.get(cacheKey);
      }
      throw NoConnectionApiException();
    }

    try {
      final uri = Uri.parse('$baseUrl$path')
          .replace(queryParameters: queryParams);
      final response = await _sendWithRetry(
        path,
        (headers) =>
            _httpClient.get(uri, headers: headers).timeout(requestTimeout),
      );
      final data = _handleResponse(response);
      if (cache.isCacheablePath(path) && data != null) {
        cache.set(cacheKey, data);
      }
      if (_isOffline) {
        isOffline = false;
      }
      return data;
    } on TimeoutException catch (e) {
      isOffline = true;
      if (cache.isCacheablePath(path) && cache.has(cacheKey)) {
        return cache.get(cacheKey);
      }
      throw TimeoutApiException(
        message: e.message ?? 'The request timed out. Please try again.',
      );
    } on SocketException catch (e) {
      isOffline = true;
      if (cache.isCacheablePath(path) && cache.has(cacheKey)) {
        return cache.get(cacheKey);
      }
      throw NoConnectionApiException(message: e.message);
    } on http.ClientException catch (e) {
      isOffline = true;
      if (cache.isCacheablePath(path) && cache.has(cacheKey)) {
        return cache.get(cacheKey);
      }
      throw NoConnectionApiException(message: e.message);
    }
  }

  // Sends a POST request, rejecting offline writes with a clear notification.
  Future<dynamic> post(String path, {Object? body}) async {
    if (_isOffline) {
      throw OfflineWriteApiException();
    }

    try {
      final uri = Uri.parse('$baseUrl$path');
      final encoded = body != null ? jsonEncode(body) : null;
      final response = await _sendWithRetry(
        path,
        (headers) => _httpClient
            .post(uri, headers: headers, body: encoded)
            .timeout(requestTimeout),
      );
      final data = _handleResponse(response);
      if (_isOffline) {
        isOffline = false;
      }
      return data;
    } on TimeoutException catch (e) {
      isOffline = true;
      throw TimeoutApiException(
        message: e.message ?? 'The request timed out. Please try again.',
      );
    } on SocketException {
      isOffline = true;
      throw OfflineWriteApiException();
    } on http.ClientException {
      isOffline = true;
      throw OfflineWriteApiException();
    }
  }

  // Sends a PATCH request, rejecting offline writes with a clear notification.
  Future<dynamic> patch(String path, {Object? body}) async {
    if (_isOffline) {
      throw OfflineWriteApiException();
    }

    try {
      final uri = Uri.parse('$baseUrl$path');
      final encoded = body != null ? jsonEncode(body) : null;
      final response = await _sendWithRetry(
        path,
        (headers) => _httpClient
            .patch(uri, headers: headers, body: encoded)
            .timeout(requestTimeout),
      );
      final data = _handleResponse(response);
      if (_isOffline) {
        isOffline = false;
      }
      return data;
    } on TimeoutException catch (e) {
      isOffline = true;
      throw TimeoutApiException(
        message: e.message ?? 'The request timed out. Please try again.',
      );
    } on SocketException {
      isOffline = true;
      throw OfflineWriteApiException();
    } on http.ClientException {
      isOffline = true;
      throw OfflineWriteApiException();
    }
  }

  // Sends a DELETE request, rejecting offline writes with a clear notification.
  Future<dynamic> delete(String path) async {
    if (_isOffline) {
      throw OfflineWriteApiException();
    }

    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _sendWithRetry(
        path,
        (headers) =>
            _httpClient.delete(uri, headers: headers).timeout(requestTimeout),
      );
      final data = _handleResponse(response);
      if (_isOffline) {
        isOffline = false;
      }
      return data;
    } on TimeoutException catch (e) {
      isOffline = true;
      throw TimeoutApiException(
        message: e.message ?? 'The request timed out. Please try again.',
      );
    } on SocketException {
      isOffline = true;
      throw OfflineWriteApiException();
    } on http.ClientException {
      isOffline = true;
      throw OfflineWriteApiException();
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String code = 'UNKNOWN_ERROR';
    String message = 'An unexpected error occurred';
    List<Map<String, dynamic>> details = const [];

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      if (error != null) {
        code =
            error['code'] as String? ??
            (response.statusCode == 401 ? 'UNAUTHENTICATED' : code);
        message =
            error['message'] as String? ??
            (response.statusCode == 401
                ? 'Please sign in again to continue.'
                : message);
        details =
            (error['details'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            const [];
      }
    } catch (_) {
      if (response.body.isNotEmpty) message = response.body;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthApiException(
        statusCode: response.statusCode,
        code: response.statusCode == 401 ? 'UNAUTHENTICATED' : 'FORBIDDEN',
        message: message.isNotEmpty
            ? message
            : 'Please sign in again to continue.',
        details: details,
      );
    }

    if (response.statusCode == 404) {
      throw NotFoundApiException(
        code: code != 'UNKNOWN_ERROR' ? code : 'NOT_FOUND',
        message: message,
        details: details,
      );
    }

    if (response.statusCode >= 500 && response.statusCode < 600) {
      throw ServerApiException(
        statusCode: response.statusCode,
        code: code != 'UNKNOWN_ERROR' ? code : 'SERVER_ERROR',
        message: message,
        details: details,
      );
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      details: details,
    );
  }
}
