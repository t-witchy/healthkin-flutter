import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

/// API client responsible for obtaining an auth token via `/api/token/`.
class AuthTokenApi {
  final http.Client _client;

  AuthTokenApi({http.Client? client}) : _client = client ?? http.Client();

  Future<void> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/token/');

    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(
        <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      ),
    );

    // Helpful debugging in case the server returns an unexpected status/body.
    // This will show up in `flutter run` logs.
    // ignore: avoid_print
    print(
      'AuthTokenApi.login status=${response.statusCode} '
      'body=${response.body}',
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected token response format.');
    }

    final dynamic access = decoded['access'] ?? decoded['token'];
    final dynamic refresh = decoded['refresh'];

    final accessToken = access?.toString();
    final refreshToken = refresh?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Token not found in response.');
    }

    AuthSession.setTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Log the user out by blacklisting the refresh token.
  Future<void> logout() async {
    final refreshToken = AuthSession.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      // Nothing to revoke on the server; just clear locally.
      AuthSession.clear();
      return;
    }

    final uri = Uri.parse('$baseUrl/accounts/api/logout/');
    final accessToken = AuthSession.token ?? '';

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'refresh_token': refreshToken,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 205) {
      throw _buildError(response);
    }

    AuthSession.clear();
  }

  Exception _buildError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString() ??
            decoded['message']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return Exception(detail);
        }
      }
    } catch (_) {
      // ignore parsing errors; fall back to generic
    }
    return Exception('Login failed with status ${response.statusCode}.');
  }
}


