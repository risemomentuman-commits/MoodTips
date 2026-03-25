// lib/services/pattern_detection_service.dart
//
// Détecte les patterns comportementaux récurrents d'un utilisateur
// en analysant ses 30 derniers jours de check-ins IRM.
//
// Algorithme principal : corrélation de Pearson
// Seuil de validation  : r > 0.6 ET confidence > 0.65

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/detected_pattern.dart';

class PatternDetectionService {
  final SupabaseClient _supabase;

  PatternDetectionService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ─── ENTRY POINT ──────────────────────────────────────────
  /// Lance l'analyse complète des patterns pour l'utilisateur courant.
  /// À appeler après chaque check-in quotidien.
  Future<List<DetectedPattern>> analyzeAndSave({int windowDays = 30}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final checkIns = await _fetchCheckIns(userId, windowDays);
    if (checkIns.length < 10) return []; // Données insuffisantes

    final patterns = <DetectedPattern>[];

    // 1. Jours difficiles récurrents (ex : lundis)
    patterns.addAll(_detectHardDayRecurrences(userId, checkIns));

    // 2. Corrélation sommeil / score IRM
    final sleepPattern = _detectSleepScoreCorrelation(userId, checkIns);
    if (sleepPattern != null) patterns.add(sleepPattern);

    // 3. Actions les plus efficaces
    patterns.addAll(_detectEffectiveActions(userId, checkIns));

    // Filtrer uniquement les patterns significatifs
    final significant = patterns.where((p) => p.isSignificant).toList();

    // Sauvegarder (upsert) en base
    await _upsertPatterns(significant);

    return significant;
  }

  // ─── FETCH CHECK-INS ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchCheckIns(
    String userId,
    int windowDays,
  ) async {
    final since = DateTime.now()
        .subtract(Duration(days: windowDays))
        .toIso8601String()
        .substring(0, 10);

    final response = await _supabase
        .from('daily_checkins')
        .select(
          'checkin_date, irm_score, sleep_hours, sleep_quality, '
          'mental_load_events, activity_minutes, selected_actions',
        )
        .eq('user_id', userId)
        .gte('checkin_date', since)
        .order('checkin_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ─── 1. JOURS DIFFICILES RÉCURRENTS ───────────────────────
  List<DetectedPattern> _detectHardDayRecurrences(
    String userId,
    List<Map<String, dynamic>> checkIns,
  ) {
    final patterns = <DetectedPattern>[];

    // Grouper par jour de la semaine (1=lundi … 7=dimanche)
    final Map<int, List<double>> scoresByWeekday = {};
    for (final ci in checkIns) {
      final date  = DateTime.parse(ci['checkin_date'] as String);
      final score = (ci['irm_score'] as num?)?.toDouble();
      if (score == null) continue;
      scoresByWeekday.putIfAbsent(date.weekday, () => []).add(score);
    }

    for (final entry in scoresByWeekday.entries) {
      final weekday = entry.key;
      final scores  = entry.value;
      if (scores.length < 3) continue;

      final mean = _mean(scores);
      final globalMean = _mean(
        checkIns
          .map((ci) => (ci['irm_score'] as num?)?.toDouble())
          .whereType<double>()
          .toList(),
      );

      // Jour difficile si moyenne -10 pts sous la moyenne globale
      if (mean < globalMean - 10) {
        final dayName = _weekdayName(weekday);
        final delta   = mean - globalMean;
        final confidence = min(1.0, scores.length / 8.0);

        patterns.add(DetectedPattern(
          id:          '',
          userId:      userId,
          patternType: PatternType.hardDayRecurrence,
          label:       'Les $dayName sont souvent difficiles '
                       '(${delta.toStringAsFixed(0)} pts en moyenne)',
          strength:    (delta / 50.0).clamp(-1.0, 1.0), // Normalise sur ±50 pts
          confidence:  confidence,
          sampleSize:  scores.length,
          metadata: {
            'weekday':      weekday,
            'weekday_name': dayName,
            'mean_score':   double.parse(mean.toStringAsFixed(1)),
            'global_mean':  double.parse(globalMean.toStringAsFixed(1)),
            'delta':        double.parse(delta.toStringAsFixed(1)),
          },
          lastSeenAt: DateTime.now(),
          detectedAt: DateTime.now(),
        ));
      }
    }

    return patterns;
  }

  // ─── 2. CORRÉLATION SOMMEIL / SCORE IRM ───────────────────
  DetectedPattern? _detectSleepScoreCorrelation(
    String userId,
    List<Map<String, dynamic>> checkIns,
  ) {
    final xValues = <double>[]; // Heures de sommeil
    final yValues = <double>[]; // Score IRM

    for (final ci in checkIns) {
      final sleep = (ci['sleep_hours'] as num?)?.toDouble();
      final score = (ci['irm_score']   as num?)?.toDouble();
      if (sleep != null && score != null) {
        xValues.add(sleep);
        yValues.add(score);
      }
    }

    if (xValues.length < 10) return null;

    final r = _pearsonCorrelation(xValues, yValues);
    if (r.abs() < 0.45) return null; // Pas assez corrélé

    // Calculer l'impact moyen d'une heure de sommeil en plus
    final slope    = _linearRegressionSlope(xValues, yValues);
    final confidence = min(1.0, (r.abs() - 0.45) / 0.35 + 0.5);

    return DetectedPattern(
      id:          '',
      userId:      userId,
      patternType: PatternType.sleepScoreCorrelation,
      label:       r > 0
          ? 'Plus tu dors, meilleur est ton score '
            '(+${slope.toStringAsFixed(1)} pts / heure de sommeil)'
          : 'Lien inhabituel entre sommeil et score détecté',
      strength:    r.clamp(-1.0, 1.0),
      confidence:  confidence.clamp(0.0, 1.0),
      sampleSize:  xValues.length,
      metadata: {
        'pearson_r':           double.parse(r.toStringAsFixed(3)),
        'slope_pts_per_hour':  double.parse(slope.toStringAsFixed(2)),
        'avg_sleep_hours':     double.parse(_mean(xValues).toStringAsFixed(1)),
        'avg_irm_score':       double.parse(_mean(yValues).toStringAsFixed(1)),
      },
      lastSeenAt: DateTime.now(),
      detectedAt: DateTime.now(),
    );
  }

  // ─── 3. ACTIONS EFFICACES ─────────────────────────────────
  List<DetectedPattern> _detectEffectiveActions(
    String userId,
    List<Map<String, dynamic>> checkIns,
  ) {
    final patterns = <DetectedPattern>[];

    // Collecter les scores par action sélectionnée
    final Map<String, List<double>> scoresByAction = {};
    final allScores = <double>[];

    for (final ci in checkIns) {
      final score   = (ci['irm_score'] as num?)?.toDouble();
      final actions = ci['selected_actions'] as List<dynamic>? ?? [];
      if (score == null) continue;
      allScores.add(score);
      for (final action in actions) {
        scoresByAction
            .putIfAbsent(action.toString(), () => [])
            .add(score);
      }
    }

    final globalMean = _mean(allScores);

    // Trier par impact moyen, garder le top 3
    final ranked = scoresByAction.entries
        .where((e) => e.value.length >= 4)
        .map((e) => MapEntry(e.key, _mean(e.value) - globalMean))
        .where((e) => e.value > 5) // Impact minimum +5 pts
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in ranked.take(3)) {
      final action    = entry.key;
      final delta     = entry.value;
      final scores    = scoresByAction[action]!;
      final r         = (delta / 50.0).clamp(0.0, 1.0);
      final confidence = min(1.0, scores.length / 10.0);

      patterns.add(DetectedPattern(
        id:          '',
        userId:      userId,
        patternType: PatternType.effectiveAction,
        label:       '"$action" est associé à +${delta.toStringAsFixed(0)} pts '
                     'sur ton score IRM',
        strength:    r,
        confidence:  confidence,
        sampleSize:  scores.length,
        metadata: {
          'action':       action,
          'avg_delta':    double.parse(delta.toStringAsFixed(1)),
          'action_mean':  double.parse(_mean(scores).toStringAsFixed(1)),
          'global_mean':  double.parse(globalMean.toStringAsFixed(1)),
          'occurrences':  scores.length,
        },
        lastSeenAt: DateTime.now(),
        detectedAt: DateTime.now(),
      ));
    }

    return patterns;
  }

  // ─── UPSERT EN BASE ───────────────────────────────────────
  Future<void> _upsertPatterns(List<DetectedPattern> patterns) async {
    if (patterns.isEmpty) return;

    for (final pattern in patterns) {
      // Cherche si un pattern du même type existe déjà
      final existing = await _supabase
          .from('detected_patterns')
          .select('id')
          .eq('user_id', pattern.userId)
          .eq('pattern_type', pattern.patternType.value)
          .eq('label', pattern.label)
          .maybeSingle();

      if (existing != null) {
        // Mise à jour
        await _supabase
            .from('detected_patterns')
            .update({
              'strength':     pattern.strength,
              'confidence':   pattern.confidence,
              'sample_size':  pattern.sampleSize,
              'metadata':     pattern.metadata,
              'last_seen_at': pattern.lastSeenAt.toIso8601String().substring(0, 10),
            })
            .eq('id', existing['id'] as String);
      } else {
        // Insertion
        await _supabase
            .from('detected_patterns')
            .insert(pattern.toJson());
      }
    }
  }

  // ─── RÉCUPÉRER LES PATTERNS EXISTANTS ─────────────────────
  Future<List<DetectedPattern>> getPatterns({
    PatternType? type,
    bool significantOnly = true,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Construire la requête SANS chaîner après order
    List<dynamic> response;

    if (type != null) {
      response = await _supabase
          .from('detected_patterns')
          .select()
          .eq('user_id', userId)
          .eq('pattern_type', type.value)
          .order('confidence', ascending: false);
    } else {
      response = await _supabase
          .from('detected_patterns')
          .select()
          .eq('user_id', userId)
          .order('confidence', ascending: false);
    }

    final patterns = response
        .map((json) => DetectedPattern.fromJson(json as Map<String, dynamic>))
        .toList();

    if (significantOnly) {
      return patterns.where((p) => p.isSignificant).toList();
    }
    return patterns;
  }

  // ─── UTILITAIRES STATISTIQUES ─────────────────────────────
  double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _pearsonCorrelation(List<double> x, List<double> y) {
    assert(x.length == y.length);
    final n  = x.length;
    final mx = _mean(x);
    final my = _mean(y);

    double num = 0, dx = 0, dy = 0;
    for (int i = 0; i < n; i++) {
      num += (x[i] - mx) * (y[i] - my);
      dx  += pow(x[i] - mx, 2);
      dy  += pow(y[i] - my, 2);
    }
    final denom = sqrt(dx * dy);
    return denom == 0 ? 0 : num / denom;
  }

  double _linearRegressionSlope(List<double> x, List<double> y) {
    final n  = x.length;
    final mx = _mean(x);
    final my = _mean(y);
    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      num += (x[i] - mx) * (y[i] - my);
      den += pow(x[i] - mx, 2);
    }
    return den == 0 ? 0 : num / den;
  }

  String _weekdayName(int weekday) {
    const names = {
      1: 'lundis', 2: 'mardis', 3: 'mercredis',
      4: 'jeudis', 5: 'vendredis', 6: 'samedis', 7: 'dimanches',
    };
    return names[weekday] ?? 'ce jour';
  }
}