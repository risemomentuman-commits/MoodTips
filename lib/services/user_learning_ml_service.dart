// lib/services/user_learning_service.dart
//
// Cœur du ML personnalisé de l'IRM V2.
// Responsabilités :
//   1. Calculer la baseline glissante 30 jours (avec percentiles)
//   2. Ajuster automatiquement les coefficients par facteur
//   3. Appliquer les coefficients au calcul IRM
//
// À appeler : après chaque check-in + recalcul hebdo en background

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class IrmBaseline {
  final double mean;
  final double p25;
  final double p50;
  final double p75;
  final double stdDev;
  final int sampleSize;
  final String scoreCategory; // 'low' | 'normal' | 'high'

  const IrmBaseline({
    required this.mean,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.stdDev,
    required this.sampleSize,
    required this.scoreCategory,
  });
}

class AdaptiveCoefficients {
  final double sleep;
  final double activity;
  final double mentalLoad;
  final double moodBaseline;
  final double social;

  const AdaptiveCoefficients({
    this.sleep        = 1.0,
    this.activity     = 1.0,
    this.mentalLoad   = 1.0,
    this.moodBaseline = 1.0,
    this.social       = 1.0,
  });

  static const defaults = AdaptiveCoefficients();

  AdaptiveCoefficients copyWith({
    double? sleep, double? activity, double? mentalLoad,
    double? moodBaseline, double? social,
  }) => AdaptiveCoefficients(
    sleep:        sleep        ?? this.sleep,
    activity:     activity     ?? this.activity,
    mentalLoad:   mentalLoad   ?? this.mentalLoad,
    moodBaseline: moodBaseline ?? this.moodBaseline,
    social:       social       ?? this.social,
  );

  @override
  String toString() =>
    'AdaptiveCoefficients(sleep: ${sleep.toStringAsFixed(2)}, '
    'activity: ${activity.toStringAsFixed(2)}, '
    'mental: ${mentalLoad.toStringAsFixed(2)})';
}

class UserLearningService {
  final SupabaseClient _supabase;

  // Seuils pour le recalcul des coefficients
  static const int    _minSamplesForCoeffs = 15;
  static const int    _recalcEveryDays     = 7;
  static const double _coeffClampMin       = 0.5;
  static const double _coeffClampMax       = 1.8;

  UserLearningService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ─── 1. BASELINE GLISSANTE 30 JOURS ───────────────────────

  /// Calcule la baseline personnalisée de l'utilisateur.
  /// Utilise une moyenne pondérée : jours récents × 1.5 vs anciens × 0.5
  Future<IrmBaseline?> calculateBaseline30Days({int windowDays = 30}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final scores = await _fetchScores(userId, windowDays);
    if (scores.length < 7) return null;

    final baseline = _computeBaseline(scores, windowDays);

    // Sauvegarder en base
    await _saveBaseline(userId, baseline);

    return baseline;
  }

  IrmBaseline _computeBaseline(List<double> scores, int windowDays) {
    // Pondération temporelle : index 0 = plus ancien (poids 0.5) → dernier (poids 1.5)
    final n = scores.length;
    final weighted = <double>[];
    for (int i = 0; i < n; i++) {
      final w = 0.5 + (i / (n - 1)) * 1.0; // 0.5 → 1.5
      weighted.add(scores[i] * w);
    }
    final weightSum = List.generate(n, (i) => 0.5 + (i / (n - 1))).reduce((a, b) => a + b);
    final mean = weighted.reduce((a, b) => a + b) / weightSum;

    // Percentiles sur les scores bruts
    final sorted = List<double>.from(scores)..sort();
    final p25 = _percentile(sorted, 0.25);
    final p50 = _percentile(sorted, 0.50);
    final p75 = _percentile(sorted, 0.75);

    // Écart-type
    final variance = scores.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) / n;
    final stdDev   = sqrt(variance);

    // Catégorie du score actuel (basé sur la baseline)
    final lastScore = scores.last;
    String category;
    if      (lastScore < p25) category = 'low';
    else if (lastScore > p75) category = 'high';
    else                      category = 'normal';

    return IrmBaseline(
      mean:          double.parse(mean.toStringAsFixed(1)),
      p25:           double.parse(p25.toStringAsFixed(1)),
      p50:           double.parse(p50.toStringAsFixed(1)),
      p75:           double.parse(p75.toStringAsFixed(1)),
      stdDev:        double.parse(stdDev.toStringAsFixed(2)),
      sampleSize:    n,
      scoreCategory: category,
    );
  }

  // ─── 2. COEFFICIENTS ADAPTATIFS ───────────────────────────

  /// Recalcule les coefficients de chaque facteur IRM
  /// basé sur leur corrélation avec le score sur 30 jours.
  /// Formule : coeff = 1.0 + (r × 0.5) → clamp(0.5, 1.8)
  Future<AdaptiveCoefficients> recalculateCoefficients() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return AdaptiveCoefficients.defaults;

    // Vérifier si recalcul nécessaire
    final shouldRecalculate = await _shouldRecalculateCoefficients(userId);
    if (!shouldRecalculate) return await getCoefficients();

    final checkIns = await _fetchDetailedCheckIns(userId, 30);
    if (checkIns.length < _minSamplesForCoeffs) {
      return AdaptiveCoefficients.defaults;
    }

    final scores = checkIns.map((ci) => (ci['irm_score'] as num).toDouble()).toList();

    // Calculer corrélation de Pearson pour chaque facteur
    final sleepCoeff    = _factorToCoeff(checkIns, 'sleep_hours',         scores);
    final activityCoeff = _factorToCoeff(checkIns, 'activity_minutes',    scores);
    final mentalCoeff   = _factorToCoeff(checkIns, 'mental_load_events',  scores,
                                          invert: true); // Charge élevée → score bas
    final moodCoeff     = _factorToCoeff(checkIns, 'mood_raw',            scores);
    final socialCoeff   = _factorToCoeff(checkIns, 'social_score',        scores);

    final coefficients = AdaptiveCoefficients(
      sleep:        sleepCoeff,
      activity:     activityCoeff,
      mentalLoad:   mentalCoeff,
      moodBaseline: moodCoeff,
      social:       socialCoeff,
    );

    // Sauvegarder en base
    await _saveCoefficients(userId, coefficients, checkIns.length);

    return coefficients;
  }

  double _factorToCoeff(
    List<Map<String, dynamic>> checkIns,
    String factorKey,
    List<double> scores, {
    bool invert = false,
  }) {
    final factorValues = checkIns
        .map((ci) => (ci[factorKey] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    if (factorValues.length < _minSamplesForCoeffs) return 1.0;

    final alignedScores = <double>[];
    final alignedFactors = <double>[];

    for (int i = 0; i < checkIns.length; i++) {
      final v = (checkIns[i][factorKey] as num?)?.toDouble();
      if (v != null) {
        alignedFactors.add(invert ? -v : v);
        alignedScores.add(scores[i]);
      }
    }

    final r = _pearson(alignedFactors, alignedScores);

    // Formule : coeff = 1.0 + (r × 0.5)
    // r=1.0 → coeff=1.5 (facteur très impactant, on l'amplifie)
    // r=0.0 → coeff=1.0 (neutre)
    // r=-1.0 → coeff=0.5 (corrélation inverse, on réduit)
    final raw = 1.0 + (r * 0.5);
    return raw.clamp(_coeffClampMin, _coeffClampMax);
  }

  // ─── 3. CALCUL IRM AVEC COEFFICIENTS ─────────────────────

  /// Calcule le score IRM personnalisé pour un ensemble de facteurs.
  /// Remplace le calcul fixe de l'IRM V1.
  Future<double> computePersonalizedIrmScore({
    required double sleepScore,     // 0–100 normalisé
    required double activityScore,  // 0–100 normalisé
    required double mentalLoadScore,// 0–100 normalisé (inversé : charge haute = score bas)
    required double moodScore,      // 0–100 normalisé
    required double socialScore,    // 0–100 normalisé
  }) async {
    final coeffs = await getCoefficients();

    // Poids de base IRM V2
    const weights = {
      'sleep':    0.30,
      'mental':   0.25,
      'activity': 0.20,
      'mood':     0.15,
      'social':   0.10,
    };

    final rawScore =
        sleepScore     * weights['sleep']!    * coeffs.sleep        +
        mentalLoadScore* weights['mental']!   * coeffs.mentalLoad   +
        activityScore  * weights['activity']! * coeffs.activity     +
        moodScore      * weights['mood']!     * coeffs.moodBaseline +
        socialScore    * weights['social']!   * coeffs.social;

    // Normaliser (les coeffs peuvent faire dépasser 100)
    final maxPossible =
        100 * weights['sleep']!    * coeffs.sleep        +
        100 * weights['mental']!   * coeffs.mentalLoad   +
        100 * weights['activity']! * coeffs.activity     +
        100 * weights['mood']!     * coeffs.moodBaseline +
        100 * weights['social']!   * coeffs.social;

    return ((rawScore / maxPossible) * 100).clamp(0, 100);
  }

  // ─── GETTERS ──────────────────────────────────────────────

  Future<AdaptiveCoefficients> getCoefficients() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return AdaptiveCoefficients.defaults;

    final row = await _supabase
        .from('user_profiles_dynamic')
        .select(
          'sleep_impact_coefficient, activity_impact_coefficient, '
          'mental_load_impact_coefficient, mood_baseline_coefficient, '
          'social_impact_coefficient',
        )
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return AdaptiveCoefficients.defaults;

    return AdaptiveCoefficients(
      sleep:        (row['sleep_impact_coefficient']       as num?)?.toDouble() ?? 1.0,
      activity:     (row['activity_impact_coefficient']    as num?)?.toDouble() ?? 1.0,
      mentalLoad:   (row['mental_load_impact_coefficient'] as num?)?.toDouble() ?? 1.0,
      moodBaseline: (row['mood_baseline_coefficient']      as num?)?.toDouble() ?? 1.0,
      social:       (row['social_impact_coefficient']      as num?)?.toDouble() ?? 1.0,
    );
  }

  Future<IrmBaseline?> getLatestBaseline() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase
        .from('irm_baselines')
        .select()
        .eq('user_id', userId)
        .order('computed_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    return IrmBaseline(
      mean:          (row['mean_score'] as num).toDouble(),
      p25:           (row['p25']        as num).toDouble(),
      p50:           (row['p50']        as num).toDouble(),
      p75:           (row['p75']        as num).toDouble(),
      stdDev:        (row['std_dev']    as num).toDouble(),
      sampleSize:    row['sample_size'] as int,
      scoreCategory: row['score_category'] as String? ?? 'normal',
    );
  }

  // ─── HELPERS DB ───────────────────────────────────────────

  Future<List<double>> _fetchScores(String userId, int days) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    final response = await _supabase
        .from('daily_checkins')
        .select('irm_score')
        .eq('user_id', userId)
        .gte('checkin_date', since)
        .not('irm_score', 'is', null)
        .order('checkin_date', ascending: true);

    return (response as List)
        .map((r) => (r['irm_score'] as num).toDouble())
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchDetailedCheckIns(
    String userId,
    int days,
  ) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    final response = await _supabase
        .from('daily_checkins')
        .select(
          'checkin_date, irm_score, sleep_hours, activity_minutes, '
          'mental_load_events, mood_raw, social_score',
        )
        .eq('user_id', userId)
        .gte('checkin_date', since)
        .not('irm_score', 'is', null)
        .order('checkin_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _saveBaseline(String userId, IrmBaseline b) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _supabase.from('irm_baselines').upsert({
      'user_id':       userId,
      'computed_date': today,
      'window_days':   30,
      'mean_score':    b.mean,
      'p25':           b.p25,
      'p50':           b.p50,
      'p75':           b.p75,
      'std_dev':       b.stdDev,
      'sample_size':   b.sampleSize,
      'score_category':b.scoreCategory,
    }, onConflict: 'user_id,computed_date');
  }

  Future<void> _saveCoefficients(
    String userId,
    AdaptiveCoefficients c,
    int sampleSize,
  ) async {
    await _supabase.from('user_profiles_dynamic').upsert({
      'user_id':                        userId,
      'sleep_impact_coefficient':       c.sleep,
      'activity_impact_coefficient':    c.activity,
      'mental_load_impact_coefficient': c.mentalLoad,
      'mood_baseline_coefficient':      c.moodBaseline,
      'social_impact_coefficient':      c.social,
      'coefficients_updated_at':        DateTime.now().toIso8601String(),
      'coefficients_sample_size':       sampleSize,
    }, onConflict: 'user_id');
  }

  Future<bool> _shouldRecalculateCoefficients(String userId) async {
    final row = await _supabase
        .from('user_profiles_dynamic')
        .select('coefficients_updated_at, coefficients_sample_size')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return true;

    final updatedAt = row['coefficients_updated_at'] as String?;
    if (updatedAt == null) return true;

    final lastUpdate = DateTime.parse(updatedAt);
    return DateTime.now().difference(lastUpdate).inDays >= _recalcEveryDays;
  }

  // ─── STATISTIQUES ─────────────────────────────────────────

  double _percentile(List<double> sorted, double p) {
    final index = p * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower];
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - lower);
  }

  double _pearson(List<double> x, List<double> y) {
    assert(x.length == y.length);
    final n  = x.length;
    final mx = x.reduce((a, b) => a + b) / n;
    final my = y.reduce((a, b) => a + b) / n;
    double num = 0, dx = 0, dy = 0;
    for (int i = 0; i < n; i++) {
      num += (x[i] - mx) * (y[i] - my);
      dx  += pow(x[i] - mx, 2);
      dy  += pow(y[i] - my, 2);
    }
    final denom = sqrt(dx * dy);
    return denom == 0 ? 0 : num / denom;
  }
}