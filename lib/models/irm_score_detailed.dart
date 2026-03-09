class IrmScoreDetailed {
  final int score;
  final double percentage;
  final IrmFactorBreakdown sleep;
  final IrmFactorBreakdown activity;
  final IrmFactorBreakdown mentalLoad;
  final IrmFactorBreakdown emotionStability;
  final String mainFactor;
  final double confidenceLevel;
  final List<String> sourcesUsed;
  final DateTime timestamp;
  final String? triggeredBy;

  const IrmScoreDetailed({
    required this.score,
    required this.percentage,
    required this.sleep,
    required this.activity,
    required this.mentalLoad,
    required this.emotionStability,
    required this.mainFactor,
    required this.confidenceLevel,
    required this.sourcesUsed,
    required this.timestamp,
    this.triggeredBy,
  });

  factory IrmScoreDetailed.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown_details'] as Map<String, dynamic>? ?? {};
    return IrmScoreDetailed(
      score: json['score'] as int,
      percentage: (json['score_percentage'] as num).toDouble(),
      sleep: IrmFactorBreakdown.fromJson(breakdown['sleep'] ?? {}),
      activity: IrmFactorBreakdown.fromJson(breakdown['activity'] ?? {}),
      mentalLoad: IrmFactorBreakdown.fromJson(breakdown['mental_load'] ?? {}),
      emotionStability: IrmFactorBreakdown.fromJson(breakdown['emotion_stability'] ?? {}),
      mainFactor: json['main_factor'] as String? ?? 'sleep',
      confidenceLevel: (json['confidence_level'] as num?)?.toDouble() ?? 0.4,
      sourcesUsed: List<String>.from(json['sources_used'] ?? []),
      timestamp: DateTime.parse(json['timestamp'] as String),
      triggeredBy: json['triggered_by'] as String?,
    );
  }

  Map<String, dynamic> toJsonForDb() => {
    'score': score,
    'score_percentage': percentage,
    'sleep_points': sleep.points,
    'sleep_max_points': sleep.maxPoints,
    'sleep_percentage': sleep.percentage,
    'activity_points': activity.points,
    'activity_max_points': activity.maxPoints,
    'activity_percentage': activity.percentage,
    'mental_load_points': mentalLoad.points,
    'mental_load_max_points': mentalLoad.maxPoints,
    'mental_load_percentage': mentalLoad.percentage,
    'emotion_stability_points': emotionStability.points,
    'emotion_stability_max_points': emotionStability.maxPoints,
    'emotion_stability_percentage': emotionStability.percentage,
    'breakdown_details': {
      'sleep': sleep.toJson(),
      'activity': activity.toJson(),
      'mental_load': mentalLoad.toJson(),
      'emotion_stability': emotionStability.toJson(),
    },
    'main_factor': mainFactor,
    'confidence_level': confidenceLevel,
    'sources_used': sourcesUsed,
    'triggered_by': triggeredBy,
  };

  /// Niveau textuel pour l'UI
  String get levelLabel {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Bon';
    if (score >= 40) return 'Moyen';
    if (score >= 20) return 'Faible';
    return 'Critique';
  }

  @override
  String toString() => 'IrmScore($score/100 - $levelLabel)';
}

class IrmFactorBreakdown {
  final int points;
  final int maxPoints;
  final double percentage;
  final String explication;
  final String? impact;
  final String? conseil;
  final List<String> sources;

  const IrmFactorBreakdown({
    required this.points,
    required this.maxPoints,
    required this.percentage,
    required this.explication,
    this.impact,
    this.conseil,
    required this.sources,
  });

  factory IrmFactorBreakdown.fromJson(Map<String, dynamic> json) {
    return IrmFactorBreakdown(
      points: json['points'] as int? ?? 0,
      maxPoints: json['max_points'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      explication: json['explication'] as String? ?? '',
      impact: json['impact'] as String?,
      conseil: json['conseil'] as String?,
      sources: List<String>.from(json['sources'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'points': points,
    'max_points': maxPoints,
    'percentage': percentage,
    'explication': explication,
    'impact': impact,
    'conseil': conseil,
    'sources': sources,
  };

  @override
  String toString() => '$points/$maxPoints (${(percentage * 100).toInt()}%)';
}