import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown when an HTTP request returns an error status code.
class ApiException implements Exception {
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
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _httpClient;

  /// Base URL endpoint for all API requests.
  final String baseUrl;
  String? _authToken;

  /// Sets the bearer token for authenticated requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  static String get _defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001/demo-littlesteps/asia-southeast1/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5001/demo-littlesteps/asia-southeast1/api';
      }
    } catch (_) {}
    return 'http://localhost:5001/demo-littlesteps/asia-southeast1/api';
  }

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// Sends a GET request to the specified [path].
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: _headers());
    return _handleResponse(response);
  }

  /// Sends a POST request to the specified [path] with an optional [body].
  Future<dynamic> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Sends a PATCH request to the specified [path] with an optional [body].
  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.patch(
      uri,
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Sends a DELETE request to the specified [path].
  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.delete(uri, headers: _headers());
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
        code: error?['code'] as String? ?? 'UNKNOWN_ERROR',
        message: error?['message'] as String? ?? 'An unexpected error occurred',
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
        code: 'HTTP_${response.statusCode}',
        message: response.body.isNotEmpty ? response.body : 'Request failed',
      );
    }
  }
}
