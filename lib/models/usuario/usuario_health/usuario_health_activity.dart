part of '../usuario.dart';

extension UsuarioActivityExtension on Usuario {
  Future<List<HealthDataPoint>> getStepsByDate(String date, {int nDays = 1}) async {
    final hasPermission = await _health.hasPermissions(
          [healthDataTypesString["STEPS"]!],
          permissions: [healthDataPermissions["STEPS"]!],
        ) ??
        false;
    if (!hasPermission) return [];

    final parsedDate = DateTime.parse(date);
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final end = start.add(Duration(days: nDays));

    final dataPoints = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: [healthDataTypesString["STEPS"]!],
    );

    final dataPointsClean = _health.removeDuplicates(dataPoints);

    return dataPointsClean;
  }

  Future<Map<String, List<HealthDataPoint>>> getDailyTrainingsByDate(String date, {int nDays = 1}) async {
    final hasPermission = await _health.hasPermissions(
          [healthDataTypesString["WORKOUT"]!],
          permissions: [healthDataPermissions["WORKOUT"]!],
        ) ??
        false;
    if (!hasPermission) return {};

    final parsedDate = DateTime.parse(date);
    final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final end = start.add(Duration(days: nDays));

    final List<HealthDataPoint> dataPoints = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: [healthDataTypesString["WORKOUT"]!],
    );

    final dataPointsClean = _health.removeDuplicates(dataPoints);

    Map<String, List<HealthDataPoint>> tempMap = {dateKey: []};
    for (var dp in dataPointsClean) {
      if (tempMap[dateKey]!.any((element) => element.dateFrom == dp.dateFrom && element.dateTo == dp.dateTo)) {
        continue;
      }
      tempMap[dateKey]!.add(dp);
    }
    return tempMap;
  }

  Future<List<HealthDataPoint>> getTotalCaloriesBurnedByDay(String date, {int nDays = 1}) async {
    final hasPermission = await _health.hasPermissions(
          [healthDataTypesString["TOTAL_CALORIES_BURNED"]!],
          permissions: [healthDataPermissions["TOTAL_CALORIES_BURNED"]!],
        ) ??
        false;
    if (!hasPermission) return [];

    final parsedDate = DateTime.parse(date);
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final end = start.add(Duration(days: nDays));

    final dataPoints = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: [healthDataTypesString["TOTAL_CALORIES_BURNED"]!],
    );

    var dataPointsClean = _health.removeDuplicates(dataPoints);

    final filteredDataPoints = <HealthDataPoint>[];

    for (var dpc in dataPointsClean) {
      if (dpc.value is NumericHealthValue) {
        final start = dpc.dateFrom;
        final end = dpc.dateTo;

        // Skip values that represent the entire day
        if (start.hour == 0 && start.minute == 0 && start.second == 0 && end.hour == 23 && end.minute == 59 && end.second == 59) {
          continue;
        }
        // Skip values where the end date is in the future
        if (end.isAfter(DateTime.now())) {
          continue;
        }
      }
      filteredDataPoints.add(dpc);
    }

    return filteredDataPoints;
  }

  Future<int> getTotalSteps({String? date, DateTime? startDate, int nDays = 1}) async {
    final parsedDate = date != null ? DateTime.parse(date) : startDate!;
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final end = start.add(Duration(days: nDays));

    final steps = await _health.getTotalStepsInInterval(start, end);

    return steps ?? 0;
  }

  Future<Map<DateTime, double>> getTotalCaloriesBurned({String? date, DateTime? startDate, int nDays = 1}) async {
    final parsedDate = date != null ? DateTime.parse(date) : startDate!;
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    final dataPoints = await getTotalCaloriesBurnedByDay(start.toIso8601String(), nDays: nDays);

    Map<DateTime, double> tempMap = {parsedDate: 0.0};
    for (var dp in dataPoints) {
      final calValue = dp.value is NumericHealthValue ? (dp.value as NumericHealthValue).numericValue : 0.0;
      tempMap[parsedDate] = (tempMap[parsedDate] ?? 0.0) + calValue;
    }
    return tempMap;
  }

  Future<int> getTimeActivityByDate(String date) async {
    final activities = await getActivity(date);

    int minutes = 0;
    for (var activity in activities) {
      final start = activity['start'] as DateTime;
      final end = activity['end'] as DateTime;
      final duration = end.difference(start).inMinutes;
      minutes += duration;
    }

    return minutes;
  }

  Future<Map<DateTime, int>> getReadDistanceByDate(String date) async {
    final hasPermission = await _health.hasPermissions(
          [healthDataTypesString["DISTANCE_DELTA"]!],
          permissions: [healthDataPermissions["DISTANCE_DELTA"]!],
        ) ??
        false;
    if (!hasPermission) return {};

    final parsedDate = DateTime.parse(date);
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final end = start.add(const Duration(days: 1));

    final dataPoints = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: end,
      types: [healthDataTypesString["DISTANCE_DELTA"]!],
    );

    Map<DateTime, int> tempMap = {parsedDate: 0};
    for (var dp in dataPoints) {
      final calValue = dp.value is NumericHealthValue ? (dp.value as NumericHealthValue).numericValue : 0;
      tempMap[parsedDate] = (tempMap[parsedDate] ?? 0) + calValue.toInt();
    }
    return tempMap;
  }

  Future<List<Map<String, dynamic>>> getActivityFromSteps(String date) async {
    final pasosPorMinuto = 70;
    final minutosActivos = 10;
    final descansoPermitido = 10;
    final dataPoints = await getStepsByDate(date);

    // 1) Filtrar resúmenes diarios
    final segments = dataPoints.where((dp) => dp.dateFrom != dp.dateTo);

    // 2) Sumar pasos por minuto
    final Map<DateTime, int> stepsPerMinute = {};
    for (var dp in segments) {
      final pasos = dp.value is NumericHealthValue ? (dp.value as NumericHealthValue).numericValue.toInt() : 0;
      final minuto = DateTime(
        dp.dateFrom.year,
        dp.dateFrom.month,
        dp.dateFrom.day,
        dp.dateFrom.hour,
        dp.dateFrom.minute,
      );
      stepsPerMinute[minuto] = (stepsPerMinute[minuto] ?? 0) + pasos;
    }

    // 3) Buscar bloques ≥15 min con ≥100 pasos/min
    final walkingPeriods = <Map<String, dynamic>>[];
    final sortedMinutes = stepsPerMinute.keys.toList()..sort();
    DateTime? start;
    int streak = 0;

    void cerrarBloque() {
      if (start != null && streak >= minutosActivos) {
        final periodStart = start!;
        final periodEnd = periodStart.add(Duration(minutes: streak));
        final total = stepsPerMinute.entries.where((e) => !e.key.isBefore(periodStart) && e.key.isBefore(periodEnd)).fold<int>(0, (s, e) => s + e.value);
        walkingPeriods.add({
          'start': periodStart,
          'end': periodEnd,
          'durationMin': streak,
          'avgPpm': total ~/ streak,
        });
      }
    }

    for (var minute in sortedMinutes) {
      if (stepsPerMinute[minute]! >= pasosPorMinuto) {
        start ??= minute;
        streak++;
      } else {
        cerrarBloque();
        start = null;
        streak = 0;
      }
    }
    cerrarBloque();

    // 4) Unir bloques separados por <10 min
    final merged = <Map<String, dynamic>>[];
    for (var period in walkingPeriods) {
      if (merged.isEmpty) {
        merged.add(Map.from(period));
        continue;
      }
      final last = merged.last;
      final gap = (period['start'] as DateTime).difference(last['end'] as DateTime).inMinutes;
      if (gap < descansoPermitido) {
        // fusionar
        final newStart = last['start'] as DateTime;
        final newEnd = period['end'] as DateTime;
        final newDur = newEnd.difference(newStart).inMinutes;
        final totalPasos = stepsPerMinute.entries.where((e) => !e.key.isBefore(newStart) && e.key.isBefore(newEnd)).fold<int>(0, (s, e) => s + e.value);
        last
          ..['end'] = newEnd
          ..['durationMin'] = newDur
          ..['avgPpm'] = totalPasos ~/ newDur;
      } else {
        merged.add(Map.from(period));
      }
    }

    return merged;
  }

  Future<List<Map<String, dynamic>>> getActivity(String date) async {
    final steps = await getActivityFromSteps(date);
    final entrenamientos = await getDailyTrainingsByDate(date);

    final List<Map<String, dynamic>> activity = [];

    // Add workouts to the activity list
    for (var entry in entrenamientos.entries) {
      for (var workout in entry.value) {
        activity.add({
          'type': 'workout',
          'start': workout.dateFrom,
          'end': workout.dateTo,
          'activityType': (workout.value as WorkoutHealthValue).workoutActivityType.toString(),
        });
      }
    }

    // Add steps only if they don't overlap with workouts
    for (var step in steps) {
      final stepStart = step['start'] as DateTime;
      final stepEnd = step['end'] as DateTime;

      final overlaps = activity.any((act) {
        final actStart = act['start'] as DateTime;
        final actEnd = act['end'] as DateTime;
        return stepStart.isBefore(actEnd) && stepEnd.isAfter(actStart);
      });

      if (!overlaps) {
        activity.add({
          'type': 'steps',
          'start': step['start'],
          'end': step['end'],
          'durationMin': step['durationMin'],
          'avgPpm': step['avgPpm'],
        });
      }
    }

    activity.sort((a, b) => (b['start'] as DateTime).compareTo(a['start'] as DateTime));
    return activity;
  }
}
