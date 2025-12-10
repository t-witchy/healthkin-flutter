import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result model for authentication attempts against the Django backend.
class AuthResult {
  final bool success;
  final int? userId;
  final String? message;
  final bool? emailFound;
  final bool? passwordValid;
  final bool? isActive;

  AuthResult({
    required this.success,
    this.userId,
    this.message,
    this.emailFound,
    this.passwordValid,
    this.isActive,
  });

  /// Parse a JSON response from the Django `api_login_view`.
  factory AuthResult.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final status = json['status'] as String?;

    if (status == 'success') {
      return AuthResult(
        success: true,
        userId: json['user_id'] is int
            ? json['user_id'] as int
            : int.tryParse(json['user_id']?.toString() ?? ''),
        message: json['message'] as String?,
      );
    }

    // status == "fail" or anything else
    return AuthResult(
      success: false,
      message: json['message'] as String?,
      emailFound: json['email_found'] as bool?,
      passwordValid: json['password_valid'] as bool?,
      isActive: json['is_active'] as bool?,
    );
  }

  /// Generic failure used for network / parsing / unexpected-status errors.
  factory AuthResult.genericFailure([String? message]) {
    return AuthResult(
      success: false,
      message: message ?? 'Something went wrong. Please try again.',
    );
  }
}

/// Repository responsible for talking to the Django auth endpoints.
class AuthRepository {
  final String baseUrl;
  final http.Client _client;

  AuthRepository({
    this.baseUrl = 'https://web.healthkin.co.uk',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Perform a login against `/accounts/api/login/`.
  ///
  /// Sends JSON:
  /// `{ "email": "...", "password": "...", "remember_me": true|false }`
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final uri = Uri.parse('$baseUrl/accounts/api/login/');

    try {
      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'remember_me': rememberMe,
        }),
      );

      Map<String, dynamic> bodyJson;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          bodyJson = decoded;
        } else {
          debugPrint(
            'AuthRepository.login: unexpected response body type: '
            '${decoded.runtimeType}',
          );
          return AuthResult.genericFailure();
        }
      } catch (e, st) {
        debugPrint('AuthRepository.login: failed to decode JSON: $e');
        debugPrint('$st');
        return AuthResult.genericFailure();
      }

      if (response.statusCode == 200 || response.statusCode == 401) {
        return AuthResult.fromJson(
          bodyJson,
          statusCode: response.statusCode,
        );
      }

      // Any other status codes treated as generic failure
      debugPrint(
        'AuthRepository.login: unexpected status code '
        '${response.statusCode} body=$bodyJson',
      );
      return AuthResult.genericFailure();
    } catch (e, st) {
      // Network issues, timeouts, etc.
      debugPrint('AuthRepository.login: network error: $e');
      debugPrint('$st');
      return AuthResult.genericFailure();
    }
  }
}

