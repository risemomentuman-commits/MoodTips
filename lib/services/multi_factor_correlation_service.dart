// lib/services/multi_factor_correlation_service.dart
//
// Détecte les règles d'association entre combinaisons de facteurs
// et le score IRM (type Apriori simplifié).
//
// Exemples de règles détectées :
//   "Sommeil <6h ET charge >7 events → Score −25"
//   "Sport matin → Score +15% journée"
//
// Seuils :
//   Support    ≥ 0.15 (règle présente ≥15% des jours)
//   Confidence ≥ 0.70 (outcome dans 70% des cas où condition vraie)

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class FactorCondition {
  final String factor;
  final String operator;  // 'lt' | 'gt' | 'eq'
  final double threshold;

  const FactorCondition({
    required this.factor,
    required this.operator,
    required this.threshold,
  });

  bool evaluate(Map<String, dynamic> checkIn) {
    final value = (checkIn[factor] as num?)?.toDouble();
    if (value == null) return false;
    switch (operator) {
      case 'lt': return value < threshold;
      case 'gt': return value > threshold;
      case 'lte': return value <= threshold;
      case 'gte': return value >= threshold;
      default:   return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'factor': factor, 'operator': operator, 'threshold': threshold,
  };

  String get description {
    final op = operator == 'lt' ? '<'
             : operator == 'gt' ? '>'
             : operator == 'lte' ? '≤'
             : '≥';
    return '$factor $op $threshold';
  }
}

class AssociationRule {
  final String               ruleKey;
  final String               description;
  final List<FactorCondition> conditions;
  final String               outcomeMetric;  // 'score'
  final double               outcomeDelta;   // Impact moyen sur le score
  final double               support;
  final double               confidence;
  final int                  sampleSize;

  const AssociationRule({
    required this.ruleKey,
    required this.description,
    required this.conditions,
    required this.outcomeMetric,
    required this.outcomeDelta,
    required this.support,
    required this.confidence,
    required this.sampleSize,
  });

  bool get isSignificant => support >= 0.15 && confidence >= 0.70;
  bool get isNegative    => outcomeDelta < 0;

  Map<String, dynamic> toJson() => {
    'rule_key':    ruleKey,
    'description': description,
    'conditions':  conditions.map((c) => c.toJson()).toList(),
    'outcome':     {'metric': outcomeMetric, 'delta': outcomeDelta, 'direction': outcomeDelta >= 0 ? 'positive' : 'negative'},
    'support':     support,
    'confidence':  confidence,
    'sample_size': sampleSize,
  };
}

class MultiFactorCorrelationService {
  final SupabaseClient _supabase;

  // Seuils
  static const double _minSupport    = 0.15;
  static const double _minConfidence = 0.70;
  static const double _minDelta      = 8.0;  // Impact minimum ±8 pts

  // Règles candidates à tester (pré-définies)
  static const List<Map<String, dynamic>> _candidateRules = [
    {
      'key': 'short_sleep_high_load',
      'desc': 'Nuit courte + journée chargée',
      'conditions': [
        {'factor': 'sleep_points',         'operator': 'lt',  'threshold': 6.0},
        {'factor': 'mental_load_points',  'operator': 'gt',  'threshold': 7.0},
      ],
    },
    {
      'key': 'good_sleep_low_load',
      'desc': 'Bonne nuit + journée légère',
      'conditions': [
        {'factor': 'sleep_points',         'operator': 'gte', 'threshold': 7.5},
        {'factor': 'mental_load_points',  'operator': 'lt',  'threshold': 4.0},
      ],
    },
    {
      'key': 'morning_sport',
      'desc': 'Sport le matin (>30 min)',
      'conditions': [
        {'factor': 'activity_points',    'operator': 'gt',  'threshold': 30.0},
      ],
    },
    {
      'key': 'very_short_sleep',
      'desc': 'Nuit très courte (<5h)',
      'conditions': [
        {'factor': 'sleep_points',         'operator': 'lt',  'threshold': 5.0},
      ],
    },
    {
      'key': 'high_social_good_mood',
      'desc': 'Bonnes interactions sociales + humeur positive',
      'conditions': [
        {'factor': 'social_score',        'operator': 'gte', 'threshold': 7.0},
        {'factor': 'score',            'operator': 'gte', 'threshold': 7.0},
      ],
    },
    {
      'key': 'overloaded_no_sport',
      'desc': 'Surcharge mentale sans activité physique',
      'conditions': [
        {'factor': 'mental_load_points',  'operator': 'gt',  'threshold': 8.0},
        {'factor': 'activity_points',    'operator': 'lt',  'threshold': 15.0},
      ],
    },
  ];

  MultiFactorCorrelationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ─── ENTRY POINT ──────────────────────────────────────────
  Future<List<AssociationRule>> detectAndSaveRules({int windowDays = 60}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final checkIns = await _fetchCheckIns(userId, windowDays);
    if (checkIns.length < 20) return [];

    final rules = <AssociationRule>[];

    for (final candidate in _candidateRules) {
      final conditions = (candidate['conditions'] as List)
          .map((c) => FactorCondition(
                factor:    c['factor'] as String,
                operator:  c['operator'] as String,
                threshold: (c['threshold'] as num).toDouble(),
              ))
          .toList();

      final rule = _evaluateRule(
        ruleKey:     candidate['key'] as String,
        description: candidate['desc'] as String,
        conditions:  conditions,
        checkIns:    checkIns,
      );

      if (rule != null && rule.isSignificant && rule.outcomeDelta.abs() >= _minDelta) {
        rules.add(rule);
      }
    }

    // Sauvegarder les règles détectées
    await _saveRules(userId, rules);

    return rules;
  }

  // ─── ÉVALUATION D'UNE RÈGLE ───────────────────────────────
  AssociationRule? _evaluateRule({
    required String ruleKey,
    required String description,
    required List<FactorCondition> conditions,
    required List<Map<String, dynamic>> checkIns,
  }) {
    final n = checkIns.length;

    // Jours où TOUTES les conditions sont vraies
    final conditionTrue = checkIns.where((ci) =>
      conditions.every((c) => c.evaluate(ci))
    ).toList();

    final support = conditionTrue.length / n;
    if (support < _minSupport) return null;
    if (conditionTrue.length < 5) return null;

    // Score moyen quand la condition est vraie vs false
    final scoresWhenTrue  = conditionTrue
        .map((ci) => (ci['score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    final scoresWhenFalse = checkIns
        .where((ci) => !conditions.every((c) => c.evaluate(ci)))
        .map((ci) => (ci['score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    if (scoresWhenTrue.isEmpty || scoresWhenFalse.isEmpty) return null;

    final meanTrue  = scoresWhenTrue.reduce((a, b) => a + b)  / scoresWhenTrue.length;
    final meanFalse = scoresWhenFalse.reduce((a, b) => a + b) / scoresWhenFalse.length;
    final delta     = meanTrue - meanFalse;

    // Confidence : proportion de fois où le delta prédit va dans la bonne direction
    // (score < baseLine quand règle négative, ou > baseLine quand règle positive)
    final globalMean = (scoresWhenTrue + scoresWhenFalse).reduce((a, b) => a + b) /
        (scoresWhenTrue.length + scoresWhenFalse.length);

    int confirmations = 0;
    for (final score in scoresWhenTrue) {
      if (delta < 0 && score < globalMean) confirmations++;
      if (delta > 0 && score > globalMean) confirmations++;
    }
    final confidence = confirmations / scoresWhenTrue.length;
    if (confidence < _minConfidence) return null;

    // Description enrichie avec le delta
    final sign = delta >= 0 ? '+' : '';
    final enrichedDesc =
      '${conditions.map((c) => c.description).join(' ET ')} '
      '→ Score $sign${delta.toStringAsFixed(0)} pts en moyenne';

    return AssociationRule(
      ruleKey:       ruleKey,
      description:   enrichedDesc,
      conditions:    conditions,
      outcomeMetric: 'score',
      outcomeDelta:  double.parse(delta.toStringAsFixed(1)),
      support:       double.parse(support.toStringAsFixed(3)),
      confidence:    double.parse(confidence.toStringAsFixed(3)),
      sampleSize:    scoresWhenTrue.length,
    );
  }

  // ─── RÉCUPÉRER LES RÈGLES ─────────────────────────────────
  Future<List<AssociationRule>> getRules({bool significantOnly = true}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('multi_factor_correlations')
        .select()
        .eq('user_id', userId)
        .order('confidence', ascending: false);

    final rules = (response as List).map((row) {
      final conditionsJson = row['conditions'] as List<dynamic>;
      final conditions = conditionsJson.map((c) => FactorCondition(
        factor:    c['factor'] as String,
        operator:  c['operator'] as String,
        threshold: (c['threshold'] as num).toDouble(),
      )).toList();

      final outcome = row['outcome'] as Map<String, dynamic>;

      return AssociationRule(
        ruleKey:       row['rule_key']    as String,
        description:   row['description'] as String,
        conditions:    conditions,
        outcomeMetric: outcome['metric']  as String,
        outcomeDelta:  (outcome['delta']  as num).toDouble(),
        support:       (row['support']    as num).toDouble(),
        confidence:    (row['confidence'] as num).toDouble(),
        sampleSize:    row['sample_size'] as int,
      );
    }).toList();

    if (significantOnly) return rules.where((r) => r.isSignificant).toList();
    return rules;
  }

  // ─── HELPERS DB ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchCheckIns(
    String userId,
    int days,
  ) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    final response = await _supabase
        .from('irm_scores_timeline')
        .select(
          'date, score, sleep_points, activity_points, '
          'mental_load_points, score, social_score',
        )
        .eq('user_id', userId)
        .gte('date', since)
        .not('score', 'is', null)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _saveRules(String userId, List<AssociationRule> rules) async {
    for (final rule in rules) {
      await _supabase.from('multi_factor_correlations').upsert(
        {'user_id': userId, ...rule.toJson()},
        onConflict: 'user_id,rule_key',
      );
    }
  }
}