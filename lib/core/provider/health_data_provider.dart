import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// Provider responsible for loading today's steps and exercise minutes
/// from Apple Health / Google Fit via the `health` package.
class HealthDataProvider extends ChangeNotifier {
  final Health _health = Health();

  bool isLoading = false;
  String? errorMessage;

  int? stepsToday;
  int? exerciseMinutesToday;

  bool get hasData => stepsToday != null || exerciseMinutesToday != null;

  Future<void> loadToday() async {
    if (isLoading) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

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

      // Total steps for today
      final int? steps =
          await _health.getTotalStepsInInterval(startOfDay, now);

      // Exercise time (in minutes) for today
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.EXERCISE_TIME],
        startTime: startOfDay,
        endTime: now,
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


