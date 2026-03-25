// lib/services/prediction_service.dart
//
// Prédit le score IRM du lendemain en combinant :
//   • Tendance des 7 derniers jours (régression linéaire)
//   • Patterns détectés (PatternDetectionService)
//   • Pénalité calendrier (événements du lendemain)
//
// Formule :
//   predicted = baseline + Σ(delta_pattern × poids) + calendar_penalty
//   confidence = f(variance_historique, nb_données, r²_tendance)

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prediction.dart';
import '../models/detected_pattern.dart';
import 'pattern_detection_service.dart';

class PredictionService {
  final SupabaseClient         _supabase;
  final PatternDetectionService _patternService;

  PredictionService({
    SupabaseClient? supabase,
    PatternDetectionService? patternService,
  })  : _supabase        = supabase ?? Supabase.instance.client,
        _patternService  = patternService ?? PatternDetectionService();

  // ─── ENTRY POINT ──────────────────────────────────────────
  /// Calcule (ou récupère) la prédiction pour demain.
  Future<Prediction?> getPredictionForTomorrow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = tomorrow.toIso8601String().substring(0, 10);

    // Retourner la prédiction existante si elle date de moins de 3h
    final existing = await _fetchExistingPrediction(userId, tomorrowStr);
    if (existing != null) return existing;

    // Calculer une nouvelle prédiction
    return _computePrediction(userId, tomorrow);
  }

  // ─── CALCUL PRÉDICTION ────────────────────────────────────
  Future<Prediction?> _computePrediction(
    String userId,
    DateTime targetDate,
  ) async {
    final checkIns = await _fetchRecentCheckIns(userId, 14);
    if (checkIns.length < 5) return null;

    final scores = checkIns
        .map((ci) => (ci['irm_score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    // 1. Tendance 7 derniers jours
    final last7 = scores.length >= 7 ? scores.sublist(scores.length - 7) : scores;
    final trend = _linearTrend(last7);
    final baseline = last7.last + trend;

    // 2. Impact des patterns détectés
    final patterns  = await _patternService.getPatterns();
    final factors   = <ContributingFactor>[];
    double patternDelta = 0;

    // Pattern : jour de la semaine difficile ?
    final weekdayPattern = patterns
        .where((p) =>
          p.patternType == PatternType.hardDayRecurrence &&
          p.metadata['weekday'] == targetDate.weekday)
        .firstOrNull;

    if (weekdayPattern != null) {
      final delta = (weekdayPattern.metadata['delta'] as num).toDouble();
      patternDelta += delta * weekdayPattern.confidence;
      factors.add(ContributingFactor(
        name:   'trend',
        delta:  delta * weekdayPattern.confidence,
        weight: weekdayPattern.confidence,
      ));
    }

    // Pattern : action efficace programmée demain ?
    final effectiveActions = patterns
        .where((p) => p.patternType == PatternType.effectiveAction)
        .toList();
    // (dans une vraie implémentation, on lirait le calendrier pour vérifier)

    // 3. Pénalité calendrier
    final calendarPenalty = await _estimateCalendarPenalty(userId, targetDate);
    if (calendarPenalty != 0) {
      factors.add(ContributingFactor(
        name:   'calendar',
        delta:  calendarPenalty,
        weight: 0.8,
      ));
    }

    // Tendance comme facteur principal
    factors.insert(0, ContributingFactor(
      name:   'trend',
      delta:  trend,
      weight: 1.0,
    ));

    // 4. Score final
    double predictedScore = (baseline + patternDelta + calendarPenalty).clamp(0, 100);

    // 5. Confiance : basée sur la variance historique et le nb de données
    final variance   = _variance(last7);
    final dataScore  = min(1.0, last7.length / 10.0);
    final stability  = max(0.0, 1.0 - variance / 400.0); // 400 = variance max (σ=20)
    final confidence = (dataScore * 0.4 + stability * 0.6).clamp(0.3, 0.92);

    // 6. Conseil préventif
    final advice = _generatePreventiveAdvice(
      predictedScore, factors, weekdayPattern, effectiveActions,
    );

    final prediction = Prediction(
      id:                  '',
      userId:              userId,
      predictedDate:       targetDate,
      predictedScore:      double.parse(predictedScore.toStringAsFixed(1)),
      confidence:          double.parse(confidence.toStringAsFixed(2)),
      contributingFactors: factors,
      preventiveAdvice:    advice,
      createdAt:           DateTime.now(),
    );

    // Sauvegarder en base
    await _savePrediction(prediction);
    return prediction;
  }

  // ─── PÉNALITÉ CALENDRIER ──────────────────────────────────
  /// Estime l'impact du calendrier du lendemain sur le score IRM.
  /// Pour l'instant : basé sur le nb d'événements saisis dans mental_load.
  Future<double> _estimateCalendarPenalty(
    String userId,
    DateTime targetDate,
  ) async {
    // On cherche si l'utilisateur a pré-renseigné une charge mentale pour demain
    // (futur : intégration Google Calendar)
    final tomorrow = targetDate.toIso8601String().substring(0, 10);

    final row = await _supabase
        .from('daily_checkins')
        .select('mental_load_events')
        .eq('user_id', userId)
        .eq('checkin_date', tomorrow)
        .maybeSingle();

    if (row == null) return 0;

    final events = (row['mental_load_events'] as int?) ?? 0;
    if (events <= 3) return 0;
    if (events <= 6) return -5;
    if (events <= 9) return -12;
    return -20;
  }

  // ─── CONSEIL PRÉVENTIF ────────────────────────────────────
  String _generatePreventiveAdvice(
    double score,
    List<ContributingFactor> factors,
    DetectedPattern? hardDayPattern,
    List<DetectedPattern> effectiveActions,
  ) {
    if (score >= 70) {
      return "Bonne journée en vue ! Profites-en pour avancer sur tes projets importants.";
    }

    if (score < 40) {
      final topAction = effectiveActions.isNotEmpty
          ? effectiveActions.first.metadata['action'] as String?
          : null;

      if (topAction != null) {
        return "Journée potentiellement difficile. Pense à : '$topAction' — "
               "c'est ton action la plus efficace d'après tes données.";
      }
      return "Journée potentiellement difficile. Prévois des créneaux de récupération "
             "et allège ta charge mentale si possible.";
    }

    if (hardDayPattern != null) {
      return "Ce jour est souvent un peu chargé pour toi. "
             "Prépare ta soirée de la veille et prévois une pause le matin.";
    }

    return "Score IRM modéré prévu. Un bon sommeil ce soir fera la différence.";
  }

  // ─── FEEDBACK UTILISATEUR ─────────────────────────────────
  Future<void> submitFeedback({
    required String predictionId,
    required bool wasCorrect,
    double? actualScore,
  }) async {
    final accuracy = actualScore != null
        ? null // calculé côté Supabase via trigger si souhaité
        : null;

    await _supabase.from('predictions').update({
      'feedback_correct': wasCorrect,
      if (actualScore != null) 'actual_score': actualScore,
      if (accuracy   != null) 'accuracy':      accuracy,
    }).eq('id', predictionId);
  }

  // ─── HELPERS DB ───────────────────────────────────────────
  Future<Prediction?> _fetchExistingPrediction(
    String userId,
    String dateStr,
  ) async {
    final row = await _supabase
        .from('predictions')
        .select()
        .eq('user_id', userId)
        .eq('predicted_date', dateStr)
        .maybeSingle();

    if (row == null) return null;

    // Invalider si > 6h
    final createdAt = DateTime.parse(row['created_at'] as String);
    if (DateTime.now().difference(createdAt).inHours > 6) return null;

    return Prediction.fromJson(row as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> _fetchRecentCheckIns(
    String userId,
    int days,
  ) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    final response = await _supabase
        .from('daily_checkins')
        .select('checkin_date, irm_score, sleep_hours, mental_load_events')
        .eq('user_id', userId)
        .gte('checkin_date', since)
        .order('checkin_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _savePrediction(Prediction p) async {
    await _supabase.from('predictions').upsert(
      p.toJson(),
      onConflict: 'user_id,predicted_date',
    );
  }

  // ─── UTILITAIRES STATISTIQUES ─────────────────────────────
  double _linearTrend(List<double> values) {
    if (values.length < 2) return 0;
    final n  = values.length.toDouble();
    final xs = List.generate(values.length, (i) => i.toDouble());
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = values.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (int i = 0; i < values.length; i++) {
      num += (xs[i] - mx) * (values[i] - my);
      den += pow(xs[i] - mx, 2);
    }
    return den == 0 ? 0 : (num / den).clamp(-15, 15); // Max ±15 pts de tendance
  }

  double _variance(List<double> values) {
    if (values.length < 2) return 0;
    final m = values.reduce((a, b) => a + b) / values.length;
    return values.map((v) => pow(v - m, 2).toDouble()).reduce((a, b) => a + b) /
        values.length;
  }
}