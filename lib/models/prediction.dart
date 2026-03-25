// lib/models/prediction.dart

class ContributingFactor {
  final String name;     // 'sleep', 'mental_load', 'activity', etc.
  final double delta;    // Impact sur le score (+/-)
  final double weight;   // Poids utilisé pour ce facteur

  const ContributingFactor({
    required this.name,
    required this.delta,
    required this.weight,
  });

  String get label {
    switch (name) {
      case 'sleep':         return 'Sommeil';
      case 'mental_load':   return 'Charge mentale';
      case 'activity':      return 'Activité physique';
      case 'mood_baseline': return 'Humeur de base';
      case 'social':        return 'Interactions sociales';
      case 'trend':         return 'Tendance 7 jours';
      case 'calendar':      return 'Agenda demain';
      default:              return name;
    }
  }

  String get emoji {
    switch (name) {
      case 'sleep':         return '😴';
      case 'mental_load':   return '🧠';
      case 'activity':      return '🏃';
      case 'mood_baseline': return '💛';
      case 'social':        return '👥';
      case 'trend':         return '📈';
      case 'calendar':      return '📅';
      default:              return '•';
    }
  }

  factory ContributingFactor.fromJson(Map<String, dynamic> json) {
    return ContributingFactor(
      name:   json['factor'] as String,
      delta:  (json['delta']  as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'factor': name,
    'delta':  delta,
    'weight': weight,
  };
}

class Prediction {
  final String id;
  final String userId;
  final DateTime predictedDate;
  final double predictedScore;         // 0–100
  final double confidence;             // 0.0–1.0
  final List<ContributingFactor> contributingFactors;
  final String? preventiveAdvice;
  final double? actualScore;           // Rempli après check-in
  final double? accuracy;              // |actual - predicted| / 100
  final bool? feedbackCorrect;
  final DateTime createdAt;

  const Prediction({
    required this.id,
    required this.userId,
    required this.predictedDate,
    required this.predictedScore,
    required this.confidence,
    required this.contributingFactors,
    this.preventiveAdvice,
    this.actualScore,
    this.accuracy,
    this.feedbackCorrect,
    required this.createdAt,
  });

  bool get isHighConfidence  => confidence >= 0.70;
  bool get isMediumConfidence => confidence >= 0.50;
  bool get isLowScore        => predictedScore < 50;
  bool get needsAttention    => isLowScore && isHighConfidence;

  String get confidenceLabel {
    if (confidence >= 0.75) return 'Élevée';
    if (confidence >= 0.55) return 'Modérée';
    return 'Faible';
  }

  String get scoreCategory {
    if (predictedScore >= 75) return 'Excellente forme';
    if (predictedScore >= 55) return 'Bonne forme';
    if (predictedScore >= 40) return 'Forme correcte';
    return 'Journée difficile prévue';
  }

  // Facteur le plus impactant (positif ou négatif)
  ContributingFactor? get dominantFactor {
    if (contributingFactors.isEmpty) return null;
    return contributingFactors.reduce(
      (a, b) => a.delta.abs() > b.delta.abs() ? a : b,
    );
  }

  factory Prediction.fromJson(Map<String, dynamic> json) {
    final factors = (json['contributing_factors'] as List<dynamic>? ?? [])
        .map((f) => ContributingFactor.fromJson(f as Map<String, dynamic>))
        .toList();

    return Prediction(
      id:                  json['id'] as String,
      userId:              json['user_id'] as String,
      predictedDate:       DateTime.parse(json['predicted_date'] as String),
      predictedScore:      (json['predicted_score'] as num).toDouble(),
      confidence:          (json['confidence'] as num).toDouble(),
      contributingFactors: factors,
      preventiveAdvice:    json['preventive_advice'] as String?,
      actualScore:         json['actual_score'] != null
                             ? (json['actual_score'] as num).toDouble()
                             : null,
      accuracy:            json['accuracy'] != null
                             ? (json['accuracy'] as num).toDouble()
                             : null,
      feedbackCorrect:     json['feedback_correct'] as bool?,
      createdAt:           DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':              userId,
    'predicted_date':       predictedDate.toIso8601String().substring(0, 10),
    'predicted_score':      predictedScore,
    'confidence':           confidence,
    'contributing_factors': contributingFactors.map((f) => f.toJson()).toList(),
    'preventive_advice':    preventiveAdvice,
  };

  @override
  String toString() =>
    'Prediction(date: ${predictedDate.toIso8601String().substring(0, 10)}, '
    'score: ${predictedScore.toStringAsFixed(1)}, '
    'confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}