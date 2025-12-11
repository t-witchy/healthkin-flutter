import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthkin_flutter/core/api/fitness_api.dart';

/// Key used in [SharedPreferences] to store the timestamp of the last
/// successful fitness sync in UTC (ISO 8601 string).
const String _kLastFitnessSyncKey = 'fitness_last_sync_utc';

/// Service responsible for reading device health data and syncing it to
/// the backend via [FitnessApi].
///
/// This is written so it can be reused both from foreground UI (e.g. a
/// "Sync now" button) and from a background task (Workmanager callback).
class FitnessSyncService {
  final Health _health;
  final FitnessApi _api;

  FitnessSyncService({
    Health? health,
    FitnessApi? api,
  })  : _health = health ?? Health(),
        _api = api ?? FitnessApi();

  /// Perform a sync of health data since the last successful run.
  ///
  /// Steps:
  /// - Determine [start] and [end] of the window to fetch:
  ///   - If we have a stored "last sync" timestamp, start from there.
  ///   - Otherwise, default to the start of today in the user's local time.
  /// - Request health permissions if needed.
  /// - Aggregate total steps and exercise minutes for the window.
  /// - Build a [FitnessActivityRecord] for the whole window and POST it.
  /// - On success, update the stored "last sync" timestamp to [end] (UTC).
  ///
  /// If auth tokens are missing, health permissions are not granted,
  /// or the user has no new data, this method returns without throwing.
  Future<void> syncNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final nowLocal = DateTime.now();
      final nowUtc = nowLocal.toUtc();

      final lastSyncIso = prefs.getString(_kLastFitnessSyncKey);
      DateTime? lastSyncUtc;
      if (lastSyncIso != null && lastSyncIso.isNotEmpty) {
        try {
          lastSyncUtc = DateTime.parse(lastSyncIso).toUtc();
        } catch (_) {
          lastSyncUtc = null;
        }
      }

      // Use last sync if available, otherwise start of today in local time.
      final startLocal = (lastSyncUtc?.toLocal()) ??
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
        await prefs.setString(
          _kLastFitnessSyncKey,
          nowUtc.toIso8601String(),
        );
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

      final record = FitnessActivityRecord(
        startTimeUtc: startLocal.toUtc(),
        endTimeUtc: nowUtc,
        localDate: nowLocal,
        stepCount: stepCount,
        exerciseMinutes: exerciseMinutes,
        activityType: activityType,
        source: source,
      );

      await _api.postActivity(record);

      await prefs.setString(
        _kLastFitnessSyncKey,
        nowUtc.toIso8601String(),
      );

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

