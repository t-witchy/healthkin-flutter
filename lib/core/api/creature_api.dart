import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/models/creature_models.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

/// Base URL for the backend API.
const String baseUrl = 'https://8cfc7bfb89ae.ngrok-free.app';

/// Retrieve the current auth token used for API calls.
String get authToken => AuthSession.token ?? '';

class CreatureApiException implements Exception {
  final String message;
  final int? statusCode;

  CreatureApiException(this.message, {this.statusCode});

  @override
  String toString() => 'CreatureApiException($statusCode): $message';
}

/// The user's currently active creature instance, as returned by
/// `/api/creatures/instances/active/`.
class ActiveCreature {
  final int id;
  final String nickname;
  final String displayName;
  final String? imageUrl;
  final int templateId;
  final String templateName;

  ActiveCreature({
    required this.id,
    required this.nickname,
    required this.displayName,
    required this.templateId,
    required this.templateName,
    this.imageUrl,
  });

  factory ActiveCreature.fromJson(Map<String, dynamic> json) {
    return ActiveCreature(
      id: json['id'] as int,
      nickname: json['nickname'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      templateId: json['template_id'] as int,
      templateName: json['template_name'] as String? ?? '',
    );
  }
}

class ActiveCreatureResponse {
  final bool hasActive;
  final ActiveCreature? creature;

  ActiveCreatureResponse({
    required this.hasActive,
    required this.creature,
  });

  factory ActiveCreatureResponse.fromJson(Map<String, dynamic> json) {
    final hasActive = json['has_active'] as bool? ?? false;
    final creatureJson = json['creature'];
    ActiveCreature? creature;
    if (hasActive && creatureJson is Map<String, dynamic>) {
      creature = ActiveCreature.fromJson(creatureJson);
    }
    return ActiveCreatureResponse(
      hasActive: hasActive,
      creature: creature,
    );
  }
}

/// Simple API client for creature-related endpoints.
class CreatureApi {
  final http.Client _client;

  CreatureApi({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _buildHeaders() {
    final token = authToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch the list of available creature templates.
  Future<List<CreatureTemplate>> fetchCreatureTemplates() async {
    final uri = Uri.parse('$baseUrl/api/creatures/templates/');
    final response = await _client.get(uri, headers: _buildHeaders());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw CreatureApiException('Unexpected response format.');
    }

    final creaturesJson = decoded['creatures'];
    return CreatureTemplate.listFromJson(creaturesJson);
  }

  /// Fetch the user's currently active creature instance.
  Future<ActiveCreatureResponse> getActiveCreature() async {
    final uri = Uri.parse('$baseUrl/api/creatures/instances/active/');
    final response = await _client.get(uri, headers: _buildHeaders());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw CreatureApiException('Unexpected response format.');
    }

    return ActiveCreatureResponse.fromJson(decoded);
  }

  /// Create the user's first creature instance.
  Future<UserCreatureInstance> chooseFirstCreature({
    required int creatureId,
    required String nickname,
  }) async {
    final uri =
        Uri.parse('$baseUrl/api/creatures/instances/choose-first/');

    final response = await _client.post(
      uri,
      headers: _buildHeaders(),
      body: jsonEncode(
        <String, dynamic>{
          'creature_id': creatureId,
          'nickname': nickname.trim(),
        },
      ),
    );

    if (response.statusCode != 201) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw CreatureApiException('Unexpected response format.');
    }

    return UserCreatureInstance.fromJson(decoded);
  }

  CreatureApiException _buildError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString();
        if (detail != null && detail.isNotEmpty) {
          // ignore: avoid_print
          print(
            'CreatureApi error status=${response.statusCode} '
            'detail=$detail',
          );
          return CreatureApiException(
            detail,
            statusCode: response.statusCode,
          );
        }
      }
    } catch (_) {
      // ignore parsing errors, fall back to generic message
    }
    // ignore: avoid_print
    print(
      'CreatureApi error status=${response.statusCode} '
      'rawBody=${response.body}',
    );
    return CreatureApiException(
      'Request failed with status ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }
}


