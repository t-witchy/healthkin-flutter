import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// Provider responsible for loading today's steps and exercise minutes
/// from Apple Health / Google Fit via the `health` package.
class HealthDataProvider extends ChangeNotifier {
  final Health _health = Health();

  bool isLoading = false;
  String? errorMessage;

  /// The date for which [stepsToday] and [exerciseMinutesToday] are loaded.
  /// This is normalized to a date-only value (no time) when set.
  DateTime? loadedDate;

  int? stepsToday;
  int? exerciseMinutesToday;

  bool get hasData => stepsToday != null || exerciseMinutesToday != null;

  /// Convenience helper that loads data for [DateTime.now()].
  Future<void> loadToday() async {
    await loadForDate(DateTime.now());
  }

  /// Load steps and exercise minutes for the given [date].
  ///
  /// If [date] is today, the range is from start-of-day until "now".
  /// For past dates, the range is the full calendar day in the user's
  /// local time.
  Future<void> loadForDate(DateTime date) async {
    if (isLoading) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final now = DateTime.now();
    final normalized = DateTime(date.year, date.month, date.day);
    final bool isToday = normalized.year == now.year &&
        normalized.month == now.month &&
        normalized.day == now.day;

    final startOfDay = normalized;
    final endOfRange = isToday
        ? now
        : startOfDay.add(const Duration(days: 1)).subtract(
              const Duration(milliseconds: 1),
            );

    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.EXERCISE_TIME,
    ];

    final permissions = <HealthDataAccess>[
      HealthDataAccess.READ,
      HealthDataAccess.READ,
    ];

    try {
      // Request permissions if needed
      final bool requested = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (!requested) {
        errorMessage = 'Health permissions not granted';
        isLoading = false;
        notifyListeners();
        return;
      }

      // Total steps for the selected day.
      final int? steps =
          await _health.getTotalStepsInInterval(startOfDay, endOfRange);

      // Exercise time (in minutes) for the selected day.
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.EXERCISE_TIME],
        startTime: startOfDay,
        endTime: endOfRange,
      );

      int totalMinutes = 0;
      for (final point in data) {
        final dynamic rawValue = point.value;
        num? numeric;

        if (rawValue is num) {
          numeric = rawValue;
        } else {
          // Fallback: try to parse from string representation of HealthValue.
          numeric = double.tryParse(rawValue.toString());
        }

        if (numeric != null) {
          totalMinutes += numeric.round();
        }
      }

      stepsToday = steps ?? 0;
      exerciseMinutesToday = totalMinutes;
      loadedDate = normalized;
      isLoading = false;
      errorMessage = null;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to load health data';
      isLoading = false;
      notifyListeners();
    }
  }
}


