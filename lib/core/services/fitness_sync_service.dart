import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;

import 'package:healthkin_flutter/core/api/creature_api.dart';
import 'package:healthkin_flutter/core/repositories/auth_session.dart';

/// Service responsible for reading device health data and syncing it to
/// the backend via `/api/fitness/`.
///
/// This is written so it can be reused both from foreground UI (e.g. a
/// "Sync now" button) and from a background task (Workmanager callback).
class FitnessSyncService {
  final Health _health;
  final http.Client _client;

  /// In-memory "last synced at" timestamp (UTC). This avoids introducing
  /// additional dependencies such as `shared_preferences`. It survives for
  /// the lifetime of the process but will reset when the app restarts.
  static DateTime? _lastSyncUtc;

  FitnessSyncService({
    Health? health,
  })  : _health = health ?? Health(),
        _client = http.Client();

  /// Perform a sync of health data since the last successful run.
  ///
  /// Steps:
  /// - Determine [start] and [end] of the window to fetch:
  ///   - If we have a stored "last sync" timestamp, start from there.
  ///   - Otherwise, default to the start of today in the user's local time.
  /// - Request health permissions if needed.
  /// - Aggregate total steps and exercise minutes for the window.
  /// - Build a [FitnessActivityRecord] for the whole window and POST it.
  /// - On success, update the in-memory "last sync" timestamp to [end] (UTC).
  ///
  /// If auth tokens are missing, health permissions are not granted,
  /// or the user has no new data, this method returns without throwing.
  Future<void> syncNow() async {
    try {
      final nowLocal = DateTime.now();
      final nowUtc = nowLocal.toUtc();

      // Use last sync if available, otherwise start of today in local time.
      final startLocal = (_lastSyncUtc?.toLocal()) ??
          DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      // If the stored last sync is somehow in the future, bail out.
      if (!startLocal.isBefore(nowLocal)) {
        debugPrint(
          'FitnessSyncService: no new window to sync '
          '(startLocal >= nowLocal).',
        );
        return;
      }

      final types = <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.EXERCISE_TIME,
      ];

      final permissions = <HealthDataAccess>[
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      // Request permissions if needed. In background this may simply fail;
      // in that case we just skip the sync and try again later.
      final bool requested = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (!requested) {
        debugPrint(
          'FitnessSyncService: health permissions not granted; '
          'skipping sync.',
        );
        return;
      }

      // Aggregate total steps for the window.
      final int? steps =
          await _health.getTotalStepsInInterval(startLocal, nowLocal);

      // Aggregate exercise time (in minutes) for the window.
      final List<HealthDataPoint> exercisePoints =
          await _health.getHealthDataFromTypes(
        types: <HealthDataType>[HealthDataType.EXERCISE_TIME],
        startTime: startLocal,
        endTime: nowLocal,
      );

      int totalMinutes = 0;
      for (final HealthDataPoint point in exercisePoints) {
        final dynamic rawValue = point.value;
        num? numeric;

        if (rawValue is num) {
          numeric = rawValue;
        } else {
          numeric = double.tryParse(rawValue.toString());
        }

        if (numeric != null) {
          totalMinutes += numeric.round();
        }
      }

      final int stepCount = steps ?? 0;
      final int exerciseMinutes = totalMinutes;

      // If there's nothing to report, just update the last sync time to
      // avoid hammering the backend with empty payloads.
      if (stepCount == 0 && exerciseMinutes == 0) {
        debugPrint(
          'FitnessSyncService: no steps or exercise minutes in window; '
          'marking as synced without POST.',
        );
        _lastSyncUtc = nowUtc;
        return;
      }

      final String source;
      if (Platform.isIOS) {
        // We are reading via Apple HealthKit; if the user is wearing an Apple
        // Watch the data will still surface through Apple Health.
        source = 'apple_health';
      } else if (Platform.isAndroid) {
        source = 'google_fit';
      } else {
        source = 'unknown';
      }

      // For now, use a generic activity type; the backend maps this onto an
      // ExerciseType record. In future we can refine this based on more
      // granular activity data.
      const String activityType = 'walking';

      // Build request payload expected by `/api/fitness/`.
      final payload = <String, dynamic>{
        'start_time': startLocal.toUtc().toIso8601String(),
        'end_time': nowUtc.toIso8601String(),
        'date': nowLocal.toIso8601String().split('T').first,
        'step_count': stepCount,
        'exercise_minutes': exerciseMinutes,
        'activity_type': activityType,
        'source': source,
      };

      final token = AuthSession.token ?? '';
      if (token.isEmpty) {
        debugPrint(
          'FitnessSyncService: no auth token available; skipping sync.',
        );
        return;
      }

      final uri = Uri.parse('$baseUrl/api/fitness/');
      final response = await _client.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        debugPrint(
          'FitnessSyncService: POST /api/fitness/ failed with '
          'status=${response.statusCode} body=${response.body}',
        );
        return;
      }

      _lastSyncUtc = nowUtc;

      debugPrint(
        'FitnessSyncService: synced steps=$stepCount '
        'exerciseMinutes=$exerciseMinutes '
        'start=$startLocal end=$nowLocal',
      );
    } catch (e, st) {
      // Log and swallow errors so that background tasks don't crash.
      debugPrint('FitnessSyncService.syncNow error: $e');
      debugPrint('$st');
    }
  }
}

