part of '../usuario.dart';

class SleepSlot {
  final DateTime start;
  final DateTime end;
  int get duration => end.difference(start).inMinutes;

  SleepSlot({required this.start, required this.end});

  factory SleepSlot.fromMap(Map<dynamic, dynamic> map) {
    final s = DateTime.fromMillisecondsSinceEpoch(map['start'] ?? 0);
    final e = DateTime.fromMillisecondsSinceEpoch(map['end'] ?? 0);
    return SleepSlot(start: s, end: e);
  }
}

extension UsuarioSleepExtension on Usuario {
  List<SleepSlot> filterAndMergeSlots(List<SleepSlot> slots, DateTime selectedDate) {
    final inicio = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final fin = inicio.add(const Duration(hours: 11));

    // Filter slots for the selected date
    final hoy = slots.where((s) => !s.start.isBefore(inicio) && s.start.isBefore(fin)).toList();
    if (hoy.isEmpty) return [];

    // Remove slots that end after the current time
    final ahora = DateTime.now();
    hoy.removeWhere((s) => s.end.isAfter(ahora));
    if (hoy.isEmpty) return [];

    // Merge slots with less than 2 minutes gap
    int tiempoTemporalVerMovil = 2;
    for (var i = 0; i < hoy.length - 1; i++) {
      final s1 = hoy[i];
      final s2 = hoy[i + 1];
      if (s1.end.isAfter(s2.start.subtract(Duration(minutes: tiempoTemporalVerMovil)))) {
        hoy[i] = SleepSlot(start: s1.start, end: s2.end);
        hoy.removeAt(i + 1);
        i--;
      }
    }

    hoy.sort((a, b) => b.duration.compareTo(a.duration));
    var principal = hoy.first;

    // Include slot from the previous day if it starts at midnight
    if (principal.start == inicio) {
      final ayer = slots.where((s) => s.start.isBefore(inicio) && s.start.isAfter(inicio.subtract(const Duration(days: 1)))).toList();
      if (ayer.isNotEmpty) {
        final ext = ayer.last;
        principal = SleepSlot(
          start: ext.start,
          end: principal.end,
        );
      }
    }

    return [principal]..sort((a, b) => a.start.compareTo(b.start));
  }

  int calculateTotalMinutes(List<SleepSlot> slots) {
    return slots.fold(0, (sum, s) => sum + s.duration);
  }

  Future<Map<String, int>> getSleepByDate(String date) async {
    final parsedDate = DateTime.parse(date);
    final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    final start = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final end = start.add(const Duration(days: 1));
    int totalSleep = 0;
    final sleepKeys = ["SLEEP_DEEP", "SLEEP_LIGHT", "SLEEP_REM", "SLEEP_ASLEEP"];
    for (var key in sleepKeys) {
      if (await _health.hasPermissions(
            [healthDataTypesString[key]!],
            permissions: [healthDataPermissions[key]!],
          ) ??
          false) {
        final dataPoints = await _health.getHealthDataFromTypes(
          startTime: start,
          endTime: end,
          types: [healthDataTypesString[key]!],
        );
        for (var dp in dataPoints) {
          final value = dp.value is NumericHealthValue ? (dp.value as NumericHealthValue).numericValue.toInt() : 0;
          totalSleep += value;
        }
      }
    }
    return {formattedDate: totalSleep};
  }

  Future<List<SleepSlot>> getSleepSlotsForDay(DateTime day) async {
    if (!await UsageStatsHelper.hasUsageStatsPermission()) {
      return [];
    }

    final formattedDay = DateFormat('yyyy-MM-dd').format(day);
    final data = await UsageStatsHelper.getInactivitySlots(formattedDay);
    return data.map((m) => SleepSlot.fromMap(m)).toList();
  }
}
