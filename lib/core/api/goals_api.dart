import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

/// Friend information attached to an active goal.
class GoalFriend {
  final int id;
  final String displayName;
  final String userIdentifier;
  final String? activeCreatureNickname;
  final String? activeCreatureImageUrl;

  GoalFriend({
    required this.id,
    required this.displayName,
    required this.userIdentifier,
    this.activeCreatureNickname,
    this.activeCreatureImageUrl,
  });

  factory GoalFriend.fromJson(Map<String, dynamic> json) {
    return GoalFriend(
      id: json['id'] as int,
      displayName: json['display_name'] as String? ?? '',
      userIdentifier: json['user_identifier']?.toString() ?? '',
      activeCreatureNickname: json['active_creature_nickname'] as String?,
      activeCreatureImageUrl: json['active_creature_image_url'] as String?,
    );
  }
}

/// Fitness component nested inside a goal component.
class GoalFitnessGoal {
  final String goalType;
  final int? stepsTarget;
  final int? minutesTarget;
  final int? exerciseType;

  GoalFitnessGoal({
    required this.goalType,
    this.stepsTarget,
    this.minutesTarget,
    this.exerciseType,
  });

  factory GoalFitnessGoal.fromJson(Map<String, dynamic> json) {
    return GoalFitnessGoal(
      goalType: json['goal_type'] as String? ?? '',
      stepsTarget: json['steps_target'] as int?,
      minutesTarget: json['minutes_target'] as int?,
      exerciseType: json['exercise_type'] as int?,
    );
  }
}

/// Diet component nested inside a goal component.
class GoalDietGoal {
  final String goalType;
  final int? caloriesMin;
  final int? caloriesMax;

  GoalDietGoal({
    required this.goalType,
    this.caloriesMin,
    this.caloriesMax,
  });

  factory GoalDietGoal.fromJson(Map<String, dynamic> json) {
    return GoalDietGoal(
      goalType: json['goal_type'] as String? ?? '',
      caloriesMin: json['calories_min'] as int?,
      caloriesMax: json['calories_max'] as int?,
    );
  }
}

/// One component in a goal program (e.g. steps, exercise, diet).
class GoalComponent {
  final int id;
  final String title;
  final String componentType;
  final int durationDays;
  final GoalFitnessGoal? fitnessGoal;
  final GoalDietGoal? dietGoal;

  GoalComponent({
    required this.id,
    required this.title,
    required this.componentType,
    required this.durationDays,
    this.fitnessGoal,
    this.dietGoal,
  });

  factory GoalComponent.fromJson(Map<String, dynamic> json) {
    return GoalComponent(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      componentType: json['component_type'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 0,
      fitnessGoal: json['fitness_goal'] is Map<String, dynamic>
          ? GoalFitnessGoal.fromJson(
              (json['fitness_goal'] as Map).cast<String, dynamic>(),
            )
          : null,
      dietGoal: json['diet_goal'] is Map<String, dynamic>
          ? GoalDietGoal.fromJson(
              (json['diet_goal'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

/// A goal program that a user can enroll in.
class GoalProgram {
  final int id;
  final String title;
  final String? description;
  final int durationDays;
  final List<GoalComponent> components;

  GoalProgram({
    required this.id,
    required this.title,
    required this.durationDays,
    required this.components,
    this.description,
  });

  factory GoalProgram.fromJson(Map<String, dynamic> json) {
    final compsJson = json['components'];
    List<GoalComponent> components = const [];
    if (compsJson is List) {
      components = compsJson
          .whereType<Map<String, dynamic>>()
          .map(GoalComponent.fromJson)
          .toList();
    }

    return GoalProgram(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      durationDays: json['duration_days'] as int? ?? 0,
      components: components,
    );
  }

  /// Whether this goal contains a fitness component with steps target.
  bool get hasStepsComponent {
    return components.any(
      (c) => c.fitnessGoal?.goalType == 'steps',
    );
  }

  /// Whether this goal contains a fitness component with exercise minutes.
  bool get hasExerciseMinutesComponent {
    return components.any(
      (c) =>
          c.fitnessGoal != null &&
          c.fitnessGoal!.goalType != 'steps' &&
          (c.fitnessGoal!.minutesTarget ?? 0) > 0,
    );
  }
}

/// A user-specific active goal (UserProgram).
class UserGoal {
  final int userProgramId;
  final GoalProgram program;
  final String? startDate;
  final String? endDate;
  final bool isWithFriend;
  final GoalFriend? friend;

  UserGoal({
    required this.userProgramId,
    required this.program,
    required this.isWithFriend,
    this.startDate,
    this.endDate,
    this.friend,
  });

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      userProgramId: json['user_program_id'] as int,
      program: GoalProgram.fromJson(
        (json['program'] as Map).cast<String, dynamic>(),
      ),
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      isWithFriend: json['is_with_friend'] as bool? ?? false,
      friend: json['friend'] is Map<String, dynamic>
          ? GoalFriend.fromJson(
              (json['friend'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class GoalsApiException implements Exception {
  final String message;
  final int? statusCode;

  GoalsApiException(this.message, {this.statusCode});

  @override
  String toString() => 'GoalsApiException($statusCode): $message';
}

/// Pending challenge returned from `/api/goals/challenges/pending/`.
///
/// The challengee is the current user; the challenger is represented as a
/// [GoalFriend].
class GoalChallenge {
  final int id;
  final GoalProgram program;
  final GoalFriend challenger;
  final String createdAt;
  final String status;

  GoalChallenge({
    required this.id,
    required this.program,
    required this.challenger,
    required this.createdAt,
    required this.status,
  });

  factory GoalChallenge.fromJson(Map<String, dynamic> json) {
    return GoalChallenge(
      id: json['id'] as int,
      program: GoalProgram.fromJson(
        (json['program'] as Map).cast<String, dynamic>(),
      ),
      challenger: GoalFriend.fromJson(
        (json['challenger'] as Map).cast<String, dynamic>(),
      ),
      createdAt: json['created_at'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

/// API client for goal-related endpoints.
class GoalsApi {
  final http.Client _client;

  GoalsApi({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final token = AuthSession.token ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<UserGoal>> fetchActiveGoals() async {
    final uri = Uri.parse('$baseUrl/api/goals/programs/active/');
    final response = await _client.get(uri, headers: _headers());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw GoalsApiException('Unexpected active goals response format.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(UserGoal.fromJson)
        .toList();
  }

  Future<List<GoalProgram>> fetchAvailableGoals() async {
    final uri = Uri.parse('$baseUrl/api/goals/programs/available/');
    final response = await _client.get(uri, headers: _headers());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw GoalsApiException('Unexpected available goals response format.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(GoalProgram.fromJson)
        .toList();
  }

  Future<UserGoal> enrollInGoal({
    required int programId,
    DateTime? startDate,
    int? friendId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/goals/programs/enroll/');
    final now = startDate ?? DateTime.now();
    final startDateStr = now.toIso8601String().split('T').first;

    final body = <String, dynamic>{
      'program_id': programId,
      'start_date': startDateStr,
    };
    if (friendId != null) {
      body['friend_id'] = friendId;
    }

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw GoalsApiException('Unexpected enroll response format.');
    }

    return UserGoal.fromJson(decoded);
  }

  /// Create a challenge for the given program and friend.
  Future<void> createChallenge({
    required int programId,
    required int friendId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/goals/challenges/');

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'program_id': programId,
        'friend_id': friendId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildError(response);
    }
  }

  /// Fetch pending challenges for the current user.
  Future<List<GoalChallenge>> fetchPendingChallenges() async {
    final uri = Uri.parse('$baseUrl/api/goals/challenges/pending/');
    final response = await _client.get(uri, headers: _headers());

    if (response.statusCode != 200) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw GoalsApiException('Unexpected challenges response format.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(GoalChallenge.fromJson)
        .toList();
  }

  /// Accept a pending challenge and return the new [UserGoal].
  Future<UserGoal> acceptChallenge(int id) async {
    final uri = Uri.parse('$baseUrl/api/goals/challenges/$id/accept/');

    final response = await _client.post(
      uri,
      headers: _headers(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw GoalsApiException('Unexpected accept response format.');
    }

    return UserGoal.fromJson(decoded);
  }

  GoalsApiException _buildError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail =
            decoded['detail']?.toString() ?? decoded['message']?.toString();
        if (detail != null && detail.isNotEmpty) {
          return GoalsApiException(
            detail,
            statusCode: response.statusCode,
          );
        }
      }
    } catch (_) {
      // ignore
    }

    return GoalsApiException(
      'Request failed with status ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }
}


