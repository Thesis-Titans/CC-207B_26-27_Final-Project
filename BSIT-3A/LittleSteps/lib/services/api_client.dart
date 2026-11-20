import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown when an HTTP request returns an error status code.
class ApiException implements Exception {
  /// Creates an [ApiException] with status code, error code, message and details.
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const [],
  });

  /// HTTP status code returned by the server.
  final int statusCode;

  /// Error code identifying the failure reason.
  final String code;

  /// Human-readable error description.
  final String message;

  /// Additional error detail objects.
  final List<Map<String, dynamic>> details;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}

/// HTTP client for interacting with the backend API.
///
/// Attaches verified ID tokens on calls to protected endpoints, handles automatic
/// token refresh on 401, and notifies listeners upon session expiration.
class ApiClient {
  /// Creates an [ApiClient].
  ApiClient({
    String? baseUrl,
    String? host,
    http.Client? httpClient,
    this.tokenProvider,
    this.onRefreshToken,
    this.onSessionExpired,
  }) : _httpClient = httpClient ?? http.Client(),
       baseUrl = baseUrl ?? defaultBaseUrl(host: host);

  final http.Client _httpClient;

  /// Base URL endpoint for all API requests.
  final String baseUrl;

  String? _authToken;

  /// Optional provider function returning the active authentication token.
  final String? Function()? tokenProvider;

  /// Optional callback invoked when a request returns 401 to refresh the token.
  final Future<String?> Function()? onRefreshToken;

  /// Optional callback invoked when a session has unrecoverably expired.
  final VoidCallback? onSessionExpired;

  /// Current active authorization token.
  String? get authToken => tokenProvider?.call() ?? _authToken;

  /// Sets the bearer token for authenticated requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Returns the default host based on runtime platform (10.0.2.2 for Android emulator).
  static String get defaultHost {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }

  /// Computes default base URL with an optional configurable [host].
  static String defaultBaseUrl({String? host}) {
    final selectedHost = host ?? defaultHost;
    return 'http://$selectedHost:5001/demo-littlesteps/asia-southeast1/api';
  }

  /// Determines whether an endpoint [path] is protected by authentication.
  ///
  /// Protected endpoints include `/children`, `/plans`, `/milestones`,
  /// `/journal`, and `/books`. The activity catalog and weather endpoints
  /// remain accessible without authentication.
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

  /// Sends a GET request to the specified [path].
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: queryParams);
    final response = await _sendWithRetry(
      path,
      (headers) => _httpClient.get(uri, headers: headers),
    );
    return _handleResponse(response);
  }

  /// Sends a POST request to the specified [path] with an optional [body].
  Future<dynamic> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body != null ? jsonEncode(body) : null;
    final response = await _sendWithRetry(
      path,
      (headers) => _httpClient.post(uri, headers: headers, body: encoded),
    );
    return _handleResponse(response);
  }

  /// Sends a PATCH request to the specified [path] with an optional [body].
  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body != null ? jsonEncode(body) : null;
    final response = await _sendWithRetry(
      path,
      (headers) => _httpClient.patch(uri, headers: headers, body: encoded),
    );
    return _handleResponse(response);
  }

  /// Sends a DELETE request to the specified [path].
  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _sendWithRetry(
      path,
      (headers) => _httpClient.delete(uri, headers: headers),
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      throw ApiException(
        statusCode: response.statusCode,
        code:
            error?['code'] as String? ??
            (response.statusCode == 401 ? 'UNAUTHENTICATED' : 'UNKNOWN_ERROR'),
        message:
            error?['message'] as String? ??
            (response.statusCode == 401
                ? 'Please sign in again to continue.'
                : 'An unexpected error occurred'),
        details:
            (error?['details'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            const [],
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: response.statusCode,
        code: response.statusCode == 401
            ? 'UNAUTHENTICATED'
            : 'HTTP_${response.statusCode}',
        message: response.statusCode == 401
            ? 'Please sign in again to continue.'
            : (response.body.isNotEmpty ? response.body : 'Request failed'),
      );
    }
  }
}
