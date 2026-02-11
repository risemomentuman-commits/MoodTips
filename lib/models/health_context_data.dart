class HealthContextData {
  final SleepData? sleep;
  final ActivityData? activity;
  final DateTime retrievedAt;

  HealthContextData({
    this.sleep,
    this.activity,
    required this.retrievedAt,
  });
}

class SleepData {
  final double durationHours;
  final int qualityScore;

  SleepData({
    required this.durationHours,
    required this.qualityScore,
  });
}

class ActivityData {
  final int steps;
  final int activeMinutes;

  ActivityData({
    required this.steps,
    required this.activeMinutes,
  });
}

class CalendarEventData {
  final String title;
  final DateTime startTime;
  final bool isStressful;

  CalendarEventData({
    required this.title,
    required this.startTime,
    this.isStressful = false,
  });
}