// lib/models/detected_pattern.dart

enum PatternType {
  hardDayRecurrence,    // Ex : lundis difficiles
  sleepScoreCorrelation,// Corrélation sommeil / IRM
  effectiveAction,      // Action corrélée score +
  multiFactor,          // Combinaison de facteurs
}

extension PatternTypeX on PatternType {
  String get value {
    switch (this) {
      case PatternType.hardDayRecurrence:     return 'hard_day_recurrence';
      case PatternType.sleepScoreCorrelation: return 'sleep_score_correlation';
      case PatternType.effectiveAction:       return 'effective_action';
      case PatternType.multiFactor:           return 'multi_factor';
    }
  }

  static PatternType fromString(String s) {
    return PatternType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => PatternType.multiFactor,
    );
  }

  String get emoji {
    switch (this) {
      case PatternType.hardDayRecurrence:     return '📅';
      case PatternType.sleepScoreCorrelation: return '😴';
      case PatternType.effectiveAction:       return '⚡';
      case PatternType.multiFactor:           return '🔗';
    }
  }
}

class DetectedPattern {
  final String id;
  final String userId;
  final PatternType patternType;
  final String label;
  final double strength;    // Corrélation de Pearson : -1.0 → 1.0
  final double confidence;  // 0.0 → 1.0
  final int sampleSize;
  final Map<String, dynamic> metadata;
  final DateTime lastSeenAt;
  final DateTime detectedAt;

  const DetectedPattern({
    required this.id,
    required this.userId,
    required this.patternType,
    required this.label,
    required this.strength,
    required this.confidence,
    required this.sampleSize,
    required this.metadata,
    required this.lastSeenAt,
    required this.detectedAt,
  });

  // Seuils de validation
  bool get isSignificant => strength.abs() >= 0.6 && confidence >= 0.65;
  bool get isStrong      => strength.abs() >= 0.75;
  bool get isPositive    => strength > 0;

  String get strengthLabel {
    final abs = strength.abs();
    if (abs >= 0.75) return 'Fort';
    if (abs >= 0.6)  return 'Modéré';
    return 'Faible';
  }

  factory DetectedPattern.fromJson(Map<String, dynamic> json) {
    return DetectedPattern(
      id:          json['id'] as String,
      userId:      json['user_id'] as String,
      patternType: PatternTypeX.fromString(json['pattern_type'] as String),
      label:       json['label'] as String,
      strength:    (json['strength'] as num).toDouble(),
      confidence:  (json['confidence'] as num).toDouble(),
      sampleSize:  json['sample_size'] as int,
      metadata:    Map<String, dynamic>.from(json['metadata'] ?? {}),
      lastSeenAt:  DateTime.parse(json['last_seen_at'] as String),
      detectedAt:  DateTime.parse(json['detected_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':      userId,
    'pattern_type': patternType.value,
    'label':        label,
    'strength':     strength,
    'confidence':   confidence,
    'sample_size':  sampleSize,
    'metadata':     metadata,
    'last_seen_at': lastSeenAt.toIso8601String().substring(0, 10),
  };

  DetectedPattern copyWith({
    double? strength,
    double? confidence,
    int? sampleSize,
    Map<String, dynamic>? metadata,
    DateTime? lastSeenAt,
  }) {
    return DetectedPattern(
      id:          id,
      userId:      userId,
      patternType: patternType,
      label:       label,
      strength:    strength    ?? this.strength,
      confidence:  confidence  ?? this.confidence,
      sampleSize:  sampleSize  ?? this.sampleSize,
      metadata:    metadata    ?? this.metadata,
      lastSeenAt:  lastSeenAt  ?? this.lastSeenAt,
      detectedAt:  detectedAt,
    );
  }

  @override
  String toString() =>
    'DetectedPattern(type: ${patternType.value}, '
    'strength: ${strength.toStringAsFixed(2)}, '
    'confidence: ${confidence.toStringAsFixed(2)}, '
    'label: $label)';
}