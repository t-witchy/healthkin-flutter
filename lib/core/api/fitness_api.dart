import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

/// Weekly steps data point returned from `/api/fitness/weekly-steps/`.
class WeeklyStepsPoint {
  final DateTime date;
  final int totalSteps;

  WeeklyStepsPoint({
    required this.date,
    required this.totalSteps,
  });

  factory WeeklyStepsPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyStepsPoint(
      date: DateTime.parse(json['date'] as String),
      totalSteps: (json['total_steps'] as int?) ?? 0,
    );
  }
}

/// Weekly exercise minutes data point returned from `/api/fitness/weekly-minutes/`.
class WeeklyMinutesPoint {
  final DateTime date;
  final int totalExerciseMinutes;

  WeeklyMinutesPoint({
    required this.date,
    required this.totalExerciseMinutes,
  });

  factory WeeklyMinutesPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyMinutesPoint(
      date: DateTime.parse(json['date'] as String),
      totalExerciseMinutes: (json['total_exercise_minutes'] as int?) ?? 0,
    );
  }
}

class FitnessApiException implements Exception {
  final String message;
  final int? statusCode;

  FitnessApiException(this.message, {this.statusCode});

  @override
  String toString() => 'FitnessApiException($statusCode): $message';
}

/// Simple API client for fitness summary endpoints.
class FitnessApi {
  final http.Client _client;

  FitnessApi({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final token = AuthSession.token ?? '';
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<WeeklyStepsPoint>> fetchWeeklySteps({int weekOffset = 0}) async {
    final uri = Uri.parse('$baseUrl/api/fitness/weekly-steps/').replace(
      queryParameters: <String, String>{
        if (weekOffset != 0) 'week_offset': '$weekOffset',
      },
    );

    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FitnessApiException(
        'Unexpected weekly steps response format (expected List).',
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WeeklyStepsPoint.fromJson)
        .toList();
  }

  Future<List<WeeklyMinutesPoint>> fetchWeeklyMinutes({
    int weekOffset = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/fitness/weekly-minutes/').replace(
      queryParameters: <String, String>{
        if (weekOffset != 0) 'week_offset': '$weekOffset',
      },
    );

    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw FitnessApiException(
        'Unexpected weekly minutes response format (expected List).',
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WeeklyMinutesPoint.fromJson)
        .toList();
  }

  FitnessApiException _buildError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail =
            decoded['detail']?.toString() ?? decoded['message']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return FitnessApiException(
            detail,
            statusCode: response.statusCode,
          );
        }
      }
    } catch (_) {
      // ignore parsing failures, fall back to generic message below
    }

    return FitnessApiException(
      'Request failed with status ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }
}


