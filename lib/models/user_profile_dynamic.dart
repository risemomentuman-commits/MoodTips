class UserProfileDynamic {
  final String userId;
  final DateTime createdAt;
  final double baselineSleepHours;
  final int baselineSleepQuality;
  final int baselineSteps;
  final int baselineActiveMinutes;
  final double baselineMentalLoad;
  final String baselineEmotion;
  final double sleepThresholdLow;
  final double sleepThresholdOptimalMin;
  final double sleepThresholdOptimalMax;
  final int stepsThresholdLow;
  final int stepsThresholdOptimal;
  final int totalDaysData;
  final double confidenceLevel;
  final DateTime? lastBaselineUpdate;
  final DateTime updatedAt;

  const UserProfileDynamic({
    required this.userId,
    required this.createdAt,
    this.baselineSleepHours = 7.0,
    this.baselineSleepQuality = 75,
    this.baselineSteps = 8000,
    this.baselineActiveMinutes = 30,
    this.baselineMentalLoad = 5.0,
    this.baselineEmotion = 'calme',
    this.sleepThresholdLow = 6.0,
    this.sleepThresholdOptimalMin = 7.0,
    this.sleepThresholdOptimalMax = 9.0,
    this.stepsThresholdLow = 5000,
    this.stepsThresholdOptimal = 8000,
    this.totalDaysData = 0,
    this.confidenceLevel = 0.35,
    this.lastBaselineUpdate,
    required this.updatedAt,
  });

  factory UserProfileDynamic.defaultProfile(String userId) {
    return UserProfileDynamic(
      userId: userId,
      baselineSleepHours: 7.0,
      sleepThresholdOptimalMin: 6.5,
      sleepThresholdOptimalMax: 8.5,
      baselineSteps: 8000,
      baselineMentalLoad: 30,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(), 
    );
  }

  factory UserProfileDynamic.fromJson(Map<String, dynamic> json) {
    return UserProfileDynamic(
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      baselineSleepHours: (json['baseline_sleep_hours'] as num?)?.toDouble() ?? 7.0,
      baselineSleepQuality: json['baseline_sleep_quality'] as int? ?? 75,
      baselineSteps: json['baseline_steps'] as int? ?? 8000,
      baselineActiveMinutes: json['baseline_active_minutes'] as int? ?? 30,
      baselineMentalLoad: (json['baseline_mental_load'] as num?)?.toDouble() ?? 5.0,
      baselineEmotion: json['baseline_emotion'] as String? ?? 'calme',
      sleepThresholdLow: (json['sleep_threshold_low'] as num?)?.toDouble() ?? 6.0,
      sleepThresholdOptimalMin: (json['sleep_threshold_optimal_min'] as num?)?.toDouble() ?? 7.0,
      sleepThresholdOptimalMax: (json['sleep_threshold_optimal_max'] as num?)?.toDouble() ?? 9.0,
      stepsThresholdLow: json['steps_threshold_low'] as int? ?? 5000,
      stepsThresholdOptimal: json['steps_threshold_optimal'] as int? ?? 8000,
      totalDaysData: json['total_days_data'] as int? ?? 0,
      confidenceLevel: (json['confidence_level'] as num?)?.toDouble() ?? 0.35,
      lastBaselineUpdate: json['last_baseline_update'] != null
          ? DateTime.parse(json['last_baseline_update'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'baseline_sleep_hours': baselineSleepHours,
    'baseline_sleep_quality': baselineSleepQuality,
    'baseline_steps': baselineSteps,
    'baseline_active_minutes': baselineActiveMinutes,
    'baseline_mental_load': baselineMentalLoad,
    'baseline_emotion': baselineEmotion,
    'sleep_threshold_low': sleepThresholdLow,
    'sleep_threshold_optimal_min': sleepThresholdOptimalMin,
    'sleep_threshold_optimal_max': sleepThresholdOptimalMax,
    'steps_threshold_low': stepsThresholdLow,
    'steps_threshold_optimal': stepsThresholdOptimal,
    'total_days_data': totalDaysData,
    'confidence_level': confidenceLevel,
    'last_baseline_update': lastBaselineUpdate?.toIso8601String(),
  };

  UserProfileDynamic copyWith({
    double? baselineSleepHours,
    int? baselineSleepQuality,
    int? baselineSteps,
    int? baselineActiveMinutes,
    double? baselineMentalLoad,
    String? baselineEmotion,
    double? sleepThresholdLow,
    double? sleepThresholdOptimalMin,
    double? sleepThresholdOptimalMax,
    int? stepsThresholdLow,
    int? stepsThresholdOptimal,
    int? totalDaysData,
    double? confidenceLevel,
    DateTime? lastBaselineUpdate,
  }) {
    return UserProfileDynamic(
      userId: userId,
      createdAt: createdAt,
      baselineSleepHours: baselineSleepHours ?? this.baselineSleepHours,
      baselineSleepQuality: baselineSleepQuality ?? this.baselineSleepQuality,
      baselineSteps: baselineSteps ?? this.baselineSteps,
      baselineActiveMinutes: baselineActiveMinutes ?? this.baselineActiveMinutes,
      baselineMentalLoad: baselineMentalLoad ?? this.baselineMentalLoad,
      baselineEmotion: baselineEmotion ?? this.baselineEmotion,
      sleepThresholdLow: sleepThresholdLow ?? this.sleepThresholdLow,
      sleepThresholdOptimalMin: sleepThresholdOptimalMin ?? this.sleepThresholdOptimalMin,
      sleepThresholdOptimalMax: sleepThresholdOptimalMax ?? this.sleepThresholdOptimalMax,
      stepsThresholdLow: stepsThresholdLow ?? this.stepsThresholdLow,
      stepsThresholdOptimal: stepsThresholdOptimal ?? this.stepsThresholdOptimal,
      totalDaysData: totalDaysData ?? this.totalDaysData,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      lastBaselineUpdate: lastBaselineUpdate ?? this.lastBaselineUpdate,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() => 'UserProfileDynamic(userId: $userId, sleep: ${baselineSleepHours}h, steps: $baselineSteps, confidence: $confidenceLevel)';
}
