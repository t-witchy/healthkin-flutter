import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

/// Detailed status for a single fitness goal component inside a program
/// on a particular date.
class FitnessGoalComponentStatus {
  final int componentId;
  final String componentTitle;
  final String goalType;
  final double currentValue;
  final double targetValue;
  final String unit;
  final bool met;
  final int? minutesPerSession;

  FitnessGoalComponentStatus({
    required this.componentId,
    required this.componentTitle,
    required this.goalType,
    required this.currentValue,
    required this.targetValue,
    required this.unit,
    required this.met,
    this.minutesPerSession,
  });

  factory FitnessGoalComponentStatus.fromJson(Map<String, dynamic> json) {
    return FitnessGoalComponentStatus(
      componentId: (json['component_id'] as int?) ?? 0,
      componentTitle: json['component_title'] as String? ?? '',
      goalType: json['goal_type'] as String? ?? '',
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      met: json['met'] as bool? ?? false,
      minutesPerSession: json['minutes_per_session'] as int?,
    );
  }
}

/// High-level goal status for a single user program on a given date.
class UserProgramGoalStatus {
  final int userProgramId;
  final int programId;
  final String programTitle;
  final DateTime date;
  final bool isPrimary;
  final bool fitnessGoalMet;
  final List<FitnessGoalComponentStatus> fitnessGoals;

  UserProgramGoalStatus({
    required this.userProgramId,
    required this.programId,
    required this.programTitle,
    required this.date,
    required this.isPrimary,
    required this.fitnessGoalMet,
    required this.fitnessGoals,
  });

  factory UserProgramGoalStatus.fromJson(Map<String, dynamic> json) {
    final fitnessGoalsJson = json['fitness_goals'];
    List<FitnessGoalComponentStatus> fitnessGoals = const [];
    if (fitnessGoalsJson is List) {
      fitnessGoals = fitnessGoalsJson
          .whereType<Map<String, dynamic>>()
          .map(FitnessGoalComponentStatus.fromJson)
          .toList();
    }

    return UserProgramGoalStatus(
      userProgramId: (json['user_program_id'] as int?) ?? 0,
      programId: (json['program_id'] as int?) ?? 0,
      programTitle: json['program_title'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.now(),
      isPrimary: json['is_primary'] as bool? ?? false,
      fitnessGoalMet: json['fitness_goal_met'] as bool? ?? false,
      fitnessGoals: fitnessGoals,
    );
  }
}

/// Service responsible for querying high-level goal status from
/// `/api/goals/programs/status/`.
class GoalsStatusService {
  final http.Client _client;

  GoalsStatusService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final token = AuthSession.token ?? '';
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch program goal status records for the given [date].
  ///
  /// When [primaryOnly] is true, only the user's primary active program
  /// is returned by the backend (0 or 1 item).
  Future<List<UserProgramGoalStatus>> fetchProgramGoalStatus({
    DateTime? date,
    bool primaryOnly = false,
  }) async {
    final query = <String, String>{};
    if (date != null) {
      final normalized = DateTime(date.year, date.month, date.day);
      final dateStr = normalized.toIso8601String().split('T').first;
      query['date'] = dateStr;
    }
    if (primaryOnly) {
      query['primary_only'] = 'true';
    }

    final uri = Uri.parse('$baseUrl/api/goals/programs/status/')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await _client.get(uri, headers: _headers());

    if (response.statusCode != 200) {
      throw Exception(
        'GoalsStatusService: failed with status ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception(
        'GoalsStatusService: unexpected response format (expected List).',
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UserProgramGoalStatus.fromJson)
        .toList();
  }
}

