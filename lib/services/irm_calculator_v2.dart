import '../models/user_profile_dynamic.dart';
import '../models/irm_score_detailed.dart';

class IrmCalculatorV2 {
  /// Calcul principal de l'IRM V2
  static IrmScoreDetailed calculate({
    required UserProfileDynamic profile,
    required double sleepHours,
    required int steps,
    required int totalEvents,
    required int workEvents,
    required int positiveEvents,
    double meetingHours = 0,
    double weightedImpact = 0,  // ✅ NOUVEAU : impact pondéré
    required List<String> last7Emotions,
    required List<String> sources,
    String? triggeredBy,
  }) {
    // 1. Sommeil (35 pts max)
    final sleep = _calculateSleep(profile, sleepHours, sources);

    // 2. Activité (20 pts max)
    final activity = _calculateActivity(profile, steps, sources);

    // 3. Charge mentale (30 pts max) — maintenant basé sur l'impact pondéré
    final mentalLoad = _calculateMentalLoad(
      totalEvents, workEvents, positiveEvents,
      meetingHours, weightedImpact, sources,
    );

    // 4. Stabilité émotionnelle (15 pts max)
    final emotionStability = _calculateEmotionStability(
      last7Emotions, sources,
    );

    // Score total
    final totalScore = sleep.points + activity.points +
        mentalLoad.points + emotionStability.points;
    final percentage = totalScore / 100.0;

    // Facteur principal (celui avec le plus faible %)
    final mainFactor = _findMainFactor(
      sleep, activity, mentalLoad, emotionStability,
    );

    // Confiance
    final confidence = _calculateConfidence(profile, sources);

    return IrmScoreDetailed(
      score: totalScore,
      percentage: percentage,
      sleep: sleep,
      activity: activity,
      mentalLoad: mentalLoad,
      emotionStability: emotionStability,
      mainFactor: mainFactor,
      confidenceLevel: confidence,
      sourcesUsed: sources,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
    );
  }

  // ─── SOMMEIL (35 pts) ───────────────────────────────────

  static IrmFactorBreakdown _calculateSleep(
    UserProfileDynamic profile,
    double hours,
    List<String> sources,
  ) {
    int points;
    String explication;
    String? impact;
    String? conseil;

    if (hours >= profile.sleepThresholdOptimalMin &&
        hours <= profile.sleepThresholdOptimalMax) {
      points = 35;
      explication = 'Sommeil optimal : ${hours.toStringAsFixed(1)}h';
      impact = 'positif';
    } else if ((hours - profile.baselineSleepHours).abs() <= 0.5) {
      points = 30;
      explication = 'Sommeil proche de ta moyenne (${hours.toStringAsFixed(1)}h)';
      impact = 'neutre';
    } else if (hours >= 6.0 && hours < 7.0) {
      points = 20;
      explication = 'Sommeil insuffisant : ${hours.toStringAsFixed(1)}h';
      impact = 'négatif';
      conseil = 'Essaie de te coucher 30 min plus tôt ce soir';
    } else if (hours >= 5.0 && hours < 6.0) {
      points = 10;
      explication = 'Sommeil très court : ${hours.toStringAsFixed(1)}h';
      impact = 'négatif';
      conseil = 'Priorise le repos aujourd\'hui, évite les décisions importantes';
    } else if (hours < 5.0) {
      points = 0;
      explication = 'Sommeil critique : ${hours.toStringAsFixed(1)}h';
      impact = 'critique';
      conseil = 'Alerte : une sieste de 20 min est fortement recommandée';
    } else {
      // > optimal max (ex: 10h+)
      points = 25;
      explication = 'Sommeil long : ${hours.toStringAsFixed(1)}h';
      impact = 'neutre';
      conseil = 'Un sommeil trop long peut indiquer de la fatigue accumulée';
    }

    return IrmFactorBreakdown(
      points: points,
      maxPoints: 35,
      percentage: points / 35.0,
      explication: explication,
      impact: impact,
      conseil: conseil,
      sources: sources.where((s) =>
          s.contains('health') || s.contains('manual')).toList(),
    );
  }

  // ─── ACTIVITÉ (20 pts) ──────────────────────────────────
  //
  // Pondération horaire : on compare les pas au prorata de la journée
  // 6h = 0%, 12h = 50%, 18h = 85%, 22h = 100%
  // ──────────────────────────────────────────────────────────

  static IrmFactorBreakdown _calculateActivity(
    UserProfileDynamic profile,
    int steps,
    List<String> sources,
  ) {
    final now = DateTime.now();
    final hour = now.hour + (now.minute / 60.0);

    // Prorata de la journée active (6h-22h)
    double dayProgress;
    if (hour <= 6) {
      dayProgress = 0.0;
    } else if (hour >= 22) {
      dayProgress = 1.0;
    } else {
      dayProgress = (hour - 6) / 16.0; // 16h de journée active
    }

    final baseline = profile.baselineSteps > 0 ? profile.baselineSteps : 8000;
    final expectedNow = baseline * dayProgress;

    // Ratio par rapport à ce qu'on attend à cette heure
    final ratio = expectedNow > 0 ? steps / expectedNow : (steps > 0 ? 1.5 : 0.0);

    int points;
    String explication;
    String? impact;
    String? conseil;

    final hourLabel = '${hour.floor()}h${(now.minute).toString().padLeft(2, '0')}';
    final expectedLabel = expectedNow.round().toString();

    if (dayProgress < 0.15) {
      // Avant ~8h30 : trop tôt pour juger
      points = 15;
      explication = '$steps pas — début de journée, trop tôt pour évaluer';
      impact = 'neutre';
    } else if (ratio >= 1.2) {
      points = 20;
      explication = '$steps pas à $hourLabel — au-dessus du rythme !';
      impact = 'positif';
    } else if (ratio >= 0.8) {
      points = 15;
      explication = '$steps pas à $hourLabel — bon rythme (~$expectedLabel attendus)';
      impact = 'neutre';
    } else if (ratio >= 0.5) {
      points = 10;
      explication = '$steps pas à $hourLabel — en dessous du rythme (~$expectedLabel attendus)';
      impact = 'négatif';
      conseil = 'Une marche de 15 min pourrait booster ton énergie';
    } else {
      points = 5;
      explication = '$steps pas à $hourLabel — journée très sédentaire (~$expectedLabel attendus)';
      impact = 'négatif';
      conseil = 'Même 10 minutes de mouvement feront la différence';
    }

    return IrmFactorBreakdown(
      points: points,
      maxPoints: 20,
      percentage: points / 20.0,
      explication: explication,
      impact: impact,
      conseil: conseil,
      sources: sources.where((s) =>
          s.contains('health') || s.contains('steps')).toList(),
    );
  }

  // ─── CHARGE MENTALE (30 pts) ────────────────────────────
  //
  // Nouveau calcul basé sur l'impact pondéré :
  // - weightedImpact = somme(impactWeight × durée) pour chaque événement
  // - Sport/Recovery ont un impact négatif → réduisent la charge
  // - Un CODIR de 2h pèse plus qu'un déjeuner de 2h
  //
  // Échelle d'impact pondéré :
  //   0        → journée libre          → 30 pts
  //   0.1-3    → charge légère          → 25 pts
  //   3.1-6    → charge modérée         → 20 pts
  //   6.1-10   → charge élevée          → 12 pts
  //   10.1-15  → charge très élevée     → 8 pts
  //   >15      → surcharge              → 5 pts
  // ────────────────────────────────────────────────────────

  static IrmFactorBreakdown _calculateMentalLoad(
    int totalEvents,
    int workEvents,
    int positiveEvents,
    double meetingHours,
    double weightedImpact,
    List<String> sources,
  ) {
    int points;
    String explication;
    String? impact;
    String? conseil;

    // Construire la description contextuelle
    String _desc() {
      final parts = <String>[];
      parts.add('$totalEvents événement${totalEvents > 1 ? 's' : ''} restant${totalEvents > 1 ? 's' : ''}');
      if (meetingHours > 0) {
        parts.add('${meetingHours.toStringAsFixed(1)}h de réunions');
      }
      if (positiveEvents > 0) {
        parts.add('$positiveEvents régulateur${positiveEvents > 1 ? 's' : ''}');
      }
      return parts.join(' · ');
    }

    if (totalEvents == 0) {
      points = 30;
      explication = 'Plus d\'événements — journée libre';
      impact = 'positif';
    } else if (weightedImpact <= 0) {
      points = 30;
      explication = 'Que des activités de récupération — excellent';
      impact = 'positif';
    } else if (weightedImpact <= 4) {
      points = 25;
      explication = '${_desc()} — charge légère';
      impact = 'neutre';
    } else if (weightedImpact <= 8) {
      points = 20;
      explication = '${_desc()} — charge modérée';
      impact = 'neutre';
    } else if (weightedImpact <= 14) {
      points = 12;
      explication = '${_desc()} — charge élevée';
      impact = 'négatif';
      conseil = positiveEvents > 0
          ? 'Journée dense mais $positiveEvents activité(s) de récupération prévue(s)'
          : 'Journée dense — préserve ta pause déjeuner';
    } else if (weightedImpact <= 20) {
      points = 8;
      explication = '${_desc()} — charge très élevée';
      impact = 'négatif';
      conseil = 'Bloque des micro-pauses de 5min entre chaque créneau';
    } else {
      points = 5;
      explication = '${_desc()} — surcharge';
      impact = 'critique';
      conseil = 'Journée critique : délègue si possible et priorise ta récupération ce soir';
    }

    return IrmFactorBreakdown(
      points: points,
      maxPoints: 30,
      percentage: points / 30.0,
      explication: explication,
      impact: impact,
      conseil: conseil,
      sources: sources.contains('calendar') ? ['calendar'] : ['estimation'],
    );
  }

  // ─── STABILITÉ ÉMOTIONNELLE (15 pts) ────────────────────

  static IrmFactorBreakdown _calculateEmotionStability(
    List<String> last7Emotions,
    List<String> sources,
  ) {
    const negativeEmotions = [
      'stressé', 'anxieux', 'triste', 'épuisé',
      'en colère', 'frustré', 'déprimé', 'angoissé',
    ];

    final negativeDays = last7Emotions
        .where((e) => negativeEmotions.contains(e.toLowerCase()))
        .length;

    int points;
    String explication;
    String? impact;
    String? conseil;

    if (last7Emotions.isEmpty) {
      points = 8;
      explication = 'Pas assez de check-ins pour évaluer';
      impact = 'neutre';
      conseil = 'Fais tes check-ins quotidiens pour un score plus précis';
    } else if (negativeDays == 0) {
      points = 15;
      explication = 'Aucune émotion négative sur 7 jours — excellent';
      impact = 'positif';
    } else if (negativeDays <= 2) {
      points = 10;
      explication = '$negativeDays jour(s) difficile(s) sur 7';
      impact = 'neutre';
      conseil = 'Des hauts et des bas normaux, continue tes exercices';
    } else {
      points = 5;
      explication = '$negativeDays jours difficiles sur 7 — tendance à surveiller';
      impact = 'négatif';
      conseil = 'Période difficile détectée. Un exercice de respiration pourrait t\'aider';
    }

    return IrmFactorBreakdown(
      points: points,
      maxPoints: 15,
      percentage: points / 15.0,
      explication: explication,
      impact: impact,
      conseil: conseil,
      sources: sources.where((s) => s.contains('checkin')).toList(),
    );
  }

  // ─── FACTEUR PRINCIPAL ──────────────────────────────────

  static String _findMainFactor(
    IrmFactorBreakdown sleep,
    IrmFactorBreakdown activity,
    IrmFactorBreakdown mentalLoad,
    IrmFactorBreakdown emotionStability,
  ) {
    final factors = {
      'sleep': sleep.percentage,
      'activity': activity.percentage,
      'mental_load': mentalLoad.percentage,
      'emotion_stability': emotionStability.percentage,
    };
    return factors.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
  }

  // ─── CONFIANCE ──────────────────────────────────────────

  static double _calculateConfidence(
    UserProfileDynamic profile,
    List<String> sources,
  ) {
    double confidence = 0.0;

    // Données santé connectées ?
    if (sources.any((s) => s.contains('health'))) {
      confidence += 0.55;
    } else {
      confidence += 0.20;
    }

    // Calendrier connecté ?
    if (sources.any((s) => s.contains('calendar'))) {
      confidence += 0.25;
    } else {
      confidence += 0.05;
    }

    // Check-ins actifs ?
    if (sources.any((s) => s.contains('checkin'))) {
      confidence += 0.20;
    } else {
      confidence += 0.10;
    }

    // Historique suffisant ?
    if (profile.totalDaysData > 7) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }
}