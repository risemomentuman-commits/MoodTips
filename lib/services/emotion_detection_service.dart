import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/detected_emotional_state.dart';
import '../models/health_context_data.dart';
import 'health_service.dart';
import 'calendar_service.dart';

class EmotionDetectionService {

  static Future<DetectedEmotionalState> detectCurrentState() async {
    print('🧠 Début détection état émotionnel...');

    final healthData = await HealthService.getAllHealthData();
    final calendarEvents = await CalendarService.getUpcomingEvents();
    final moodHistory = await _getRecentMoodHistory();
    final now = DateTime.now();

    print('📊 Données récupérées:');
    print('  - Sommeil: ${healthData.sleep?.durationHours ?? "N/A"}h');
    print('  - Activité: ${healthData.activity?.steps ?? "N/A"} pas');
    print('  - Événements: ${calendarEvents.length}');
    print('  - Historique: ${moodHistory.length} entrées');

    return _analyzeEmotionalState(healthData, calendarEvents, moodHistory, now);
  }

  /// Récupère les 7 derniers jours d'humeur depuis Supabase
  static Future<List<Map<String, dynamic>>> _getRecentMoodHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await Supabase.instance.client
          .from('mood_logs')
          .select('emotion_id, created_at, emotions(name, type)')
          .eq('user_id', userId)
          .gte('created_at', DateTime.now().subtract(Duration(days: 7)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur historique humeur: $e');
      return [];
    }
  }

  static DetectedEmotionalState _analyzeEmotionalState(
    HealthContextData health,
    List<CalendarEventData> events,
    List<Map<String, dynamic>> moodHistory,
    DateTime now,
  ) {
    List<EmotionPrediction> predictions = [];
    List<String> reasons = [];

    final hour = now.hour;
    final dayOfWeek = now.weekday; // 1=Lundi, 7=Dimanche
    final isWeekend = dayOfWeek >= 6;
    final isMorning = hour >= 5 && hour < 12;
    final isAfternoon = hour >= 12 && hour < 18;
    final isEvening = hour >= 18 && hour < 23;

    print('⏰ Contexte: ${isMorning ? "Matin" : isAfternoon ? "Après-midi" : isEvening ? "Soir" : "Nuit"}, ${isWeekend ? "Weekend" : "Semaine"}');

    // ==========================================
    // 1. ANALYSE SOMMEIL (pondérée par heure)
    // ==========================================
    if (health.sleep != null) {
      final sleepHours = health.sleep!.durationHours;
      final sleepQuality = health.sleep!.qualityScore;

      // Sommeil insuffisant (plus pertinent le matin)
      if (sleepHours < 5) {
        final confidence = isMorning ? 0.90 : isAfternoon ? 0.75 : 0.60;
        predictions.add(EmotionPrediction(
          emotion: 'épuisé',
          confidence: confidence,
          reason: 'Sommeil très court (${sleepHours.toStringAsFixed(1)}h)',
        ));
        reasons.add('💤 Nuit très courte: ${sleepHours.toStringAsFixed(1)}h (min recommandé: 7h)');
      } else if (sleepHours < 6.5) {
        final confidence = isMorning ? 0.80 : isAfternoon ? 0.65 : 0.50;
        predictions.add(EmotionPrediction(
          emotion: 'fatigué',
          confidence: confidence,
          reason: 'Sommeil insuffisant (${sleepHours.toStringAsFixed(1)}h)',
        ));
        reasons.add('💤 Sommeil court: ${sleepHours.toStringAsFixed(1)}h (-${(7 - sleepHours).toStringAsFixed(1)}h)');
      } else if (sleepHours >= 7 && sleepHours <= 9) {
        final confidence = isMorning ? 0.75 : 0.55;
        predictions.add(EmotionPrediction(
          emotion: 'reposé',
          confidence: confidence,
          reason: 'Bon sommeil (${sleepHours.toStringAsFixed(1)}h)',
        ));
        reasons.add('💤 Nuit optimale: ${sleepHours.toStringAsFixed(1)}h ✨');
      } else if (sleepHours > 9) {
        predictions.add(EmotionPrediction(
          emotion: 'fatigué',
          confidence: 0.55,
          reason: 'Sommeil excessif (${sleepHours.toStringAsFixed(1)}h)',
        ));
        reasons.add('💤 Trop de sommeil: ${sleepHours.toStringAsFixed(1)}h (peut indiquer fatigue chronique)');
      }

      // Qualité sommeil
      if (sleepQuality < 50) {
        predictions.add(EmotionPrediction(
          emotion: 'irritable',
          confidence: 0.70,
          reason: 'Mauvaise qualité de sommeil',
        ));
        reasons.add('😴 Qualité sommeil: ${sleepQuality}% (perturbé)');
      } else if (sleepQuality >= 80) {
        predictions.add(EmotionPrediction(
          emotion: 'serein',
          confidence: 0.60,
          reason: 'Excellent sommeil',
        ));
      }
    }

    // ==========================================
    // 2. ANALYSE ACTIVITÉ (contextualisée)
    // ==========================================
    if (health.activity != null) {
      final steps = health.activity!.steps;

      // Objectif de pas adapté à l'heure
      final expectedSteps = isMorning ? 2000 :
                            isAfternoon ? 5000 :
                            isEvening ? 8000 : 3000;

      final stepsRatio = steps / expectedSteps;

      if (isMorning) {
        // Le matin, peu de pas = NORMAL, pas "fatigué"
        if (steps > 3000) {
          predictions.add(EmotionPrediction(
            emotion: 'énergique',
            confidence: 0.75,
            reason: 'Très actif ce matin ($steps pas)',
          ));
          reasons.add('🏃 Déjà $steps pas ce matin - super actif ! ⚡');
        }
        // En dessous de 3000 le matin → pas de prédiction négative
      } else if (isAfternoon) {
        if (stepsRatio < 0.4) {
          predictions.add(EmotionPrediction(
            emotion: 'fatigué',
            confidence: 0.55,
            reason: 'Faible activité en après-midi ($steps pas)',
          ));
          reasons.add('🚶 Activité faible: $steps pas (attendu ~$expectedSteps)');
        } else if (stepsRatio > 1.5) {
          predictions.add(EmotionPrediction(
            emotion: 'énergique',
            confidence: 0.70,
            reason: 'Excellente activité ($steps pas)',
          ));
          reasons.add('🏃 Très actif: $steps pas ⚡');
        }
      } else if (isEvening) {
        if (steps < 3000) {
          predictions.add(EmotionPrediction(
            emotion: 'sédentaire',
            confidence: 0.60,
            reason: 'Journée peu active ($steps pas)',
          ));
          reasons.add('🚶 Journée sédentaire: $steps pas (objectif: 8000)');
        } else if (steps > 10000) {
          predictions.add(EmotionPrediction(
            emotion: 'accompli',
            confidence: 0.75,
            reason: 'Objectif dépassé ($steps pas)',
          ));
          reasons.add('🏆 Objectif dépassé: $steps pas 🎉');
        } else if (steps >= 7000) {
          predictions.add(EmotionPrediction(
            emotion: 'énergique',
            confidence: 0.65,
            reason: 'Bonne activité ($steps pas)',
          ));
          reasons.add('✅ Bonne journée active: $steps pas');
        }
      }
    }

    // ==========================================
    // 3. ANALYSE CALENDRIER (intelligente)
    // ==========================================
    if (events.isNotEmpty) {
      final stressfulEvents = events.where((e) => e.isStressful).toList();
      final now2 = DateTime.now();

      // Événements stressants imminents
      for (var event in stressfulEvents) {
        final timeUntil = event.startTime.difference(now2);
        if (timeUntil.isNegative) continue;

        if (timeUntil.inMinutes < 30) {
          predictions.add(EmotionPrediction(
            emotion: 'stressé',
            confidence: 0.90,
            reason: 'Événement imminent: "${event.title}"',
          ));
          reasons.add('⚡ Événement dans ${timeUntil.inMinutes}min: "${event.title}"');
        } else if (timeUntil.inHours < 2) {
          predictions.add(EmotionPrediction(
            emotion: 'anxieux',
            confidence: 0.78,
            reason: 'Événement important bientôt',
          ));
          reasons.add('📅 "${event.title}" dans ${timeUntil.inHours}h${timeUntil.inMinutes % 60}min');
        } else if (timeUntil.inHours < 4) {
          predictions.add(EmotionPrediction(
            emotion: 'préoccupé',
            confidence: 0.60,
            reason: 'Événement important aujourd\'hui',
          ));
          reasons.add('📅 "${event.title}" dans ${timeUntil.inHours}h');
        }
      }

      // Journée très chargée
      final todayEvents = events.where((e) {
        final d = e.startTime;
        return d.year == now2.year && d.month == now2.month && d.day == now2.day;
      }).toList();

      if (todayEvents.length >= 6) {
        predictions.add(EmotionPrediction(
          emotion: 'débordé',
          confidence: 0.82,
          reason: 'Journée très chargée (${todayEvents.length} événements)',
        ));
        reasons.add('📆 ${todayEvents.length} événements aujourd\'hui - journée intense !');
      } else if (todayEvents.length >= 4) {
        predictions.add(EmotionPrediction(
          emotion: 'occupé',
          confidence: 0.65,
          reason: 'Journée chargée (${todayEvents.length} événements)',
        ));
        reasons.add('📆 ${todayEvents.length} événements planifiés');
      } else if (todayEvents.isEmpty && isWeekend) {
        predictions.add(EmotionPrediction(
          emotion: 'détendu',
          confidence: 0.60,
          reason: 'Weekend libre',
        ));
        reasons.add('🎉 Weekend sans contraintes !');
      }
    }

    // ==========================================
    // 4. ANALYSE HISTORIQUE HUMEUR (7 jours)
    // ==========================================
    if (moodHistory.isNotEmpty) {
      // Compter émotions négatives récentes
      final negativeEmotions = ['fatigué', 'anxieux', 'triste', 'stressé', 'épuisé', 'irritable'];
      final recentNegative = moodHistory.take(5).where((log) {
        final emotionName = log['emotions']?['name']?.toString().toLowerCase() ?? '';
        return negativeEmotions.any((neg) => emotionName.contains(neg));
      }).length;

      if (recentNegative >= 4) {
        predictions.add(EmotionPrediction(
          emotion: 'épuisé',
          confidence: 0.72,
          reason: 'Pattern négatif récurrent ($recentNegative/5 jours)',
        ));
        reasons.add('📊 Tendance: $recentNegative humeurs négatives sur 5 jours');
      } else if (recentNegative >= 3) {
        predictions.add(EmotionPrediction(
          emotion: 'fatigué',
          confidence: 0.58,
          reason: 'Quelques jours difficiles récemment',
        ));
        reasons.add('📊 Quelques jours difficiles récemment ($recentNegative/5)');
      }

      // Même heure hier → contexte habituel
      final yesterday = now.subtract(Duration(days: 1));
      final sameTimeYesterday = moodHistory.where((log) {
        try {
          final logTime = DateTime.parse(log['created_at']);
          return logTime.day == yesterday.day &&
                 (logTime.hour - now.hour).abs() < 2;
        } catch (e) { return false; }
      }).toList();

      if (sameTimeYesterday.isNotEmpty) {
        final lastMood = sameTimeYesterday.first['emotions']?['name']?.toString();
        if (lastMood != null) {
          reasons.add('📅 Hier à la même heure: $lastMood');
        }
      }
    }

    // ==========================================
    // 5. CONTEXTE JOUR DE LA SEMAINE
    // ==========================================
    if (dayOfWeek == 1 && isMorning) {
      // Lundi matin
      predictions.add(EmotionPrediction(
        emotion: 'motivé',
        confidence: 0.45,
        reason: 'Début de semaine',
      ));
      reasons.add('📅 Lundi matin - nouvelle semaine !');
    } else if (dayOfWeek == 5 && isEvening) {
      // Vendredi soir
      predictions.add(EmotionPrediction(
        emotion: 'soulagé',
        confidence: 0.55,
        reason: 'Fin de semaine de travail',
      ));
      reasons.add('🎉 Vendredi soir - weekend qui commence !');
    } else if (isWeekend && isMorning) {
      predictions.add(EmotionPrediction(
        emotion: 'détendu',
        confidence: 0.50,
        reason: 'Matin de weekend',
      ));
      reasons.add('☀️ Matin de weekend');
    }

    // ==========================================
    // 6. AGRÉGATION INTELLIGENTE
    // ==========================================

    // ✅ Fallback temporel si aucune donnée
    if (predictions.isEmpty) {
      String fallbackEmotion;
      double fallbackConfidence;
      String fallbackReason;

      if (isMorning) {
        fallbackEmotion = 'calme';
        fallbackConfidence = 0.55;
        fallbackReason = 'Début de journée détecté';
      } else if (isAfternoon) {
        fallbackEmotion = 'concentré';
        fallbackConfidence = 0.52;
        fallbackReason = 'Milieu de journée';
      } else if (isEvening) {
        fallbackEmotion = 'détendu';
        fallbackConfidence = 0.55;
        fallbackReason = 'Fin de journée';
      } else {
        fallbackEmotion = 'fatigué';
        fallbackConfidence = 0.55;
        fallbackReason = 'Heure tardive détectée';
      }

      predictions.add(EmotionPrediction(
        emotion: fallbackEmotion,
        confidence: fallbackConfidence,
        reason: fallbackReason,
      ));
      reasons.add('⏰ Analyse basée sur le contexte temporel');
    }

    // Scorer avec pondération
    Map<String, double> emotionScores = {};
    Map<String, int> emotionCount = {};

    for (var pred in predictions) {
      emotionScores[pred.emotion] =
        (emotionScores[pred.emotion] ?? 0) + pred.confidence;
      emotionCount[pred.emotion] =
        (emotionCount[pred.emotion] ?? 0) + 1;
    }

    // Bonus si plusieurs signaux confirment la même émotion
    emotionScores.forEach((emotion, score) {
      final count = emotionCount[emotion] ?? 1;
      if (count > 1) {
        emotionScores[emotion] = score * (1 + (count - 1) * 0.15);
      }
    });

    // Trier par score
    var sortedEmotions = emotionScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Normaliser la confiance (max 95%)
    final maxScore = sortedEmotions.first.value;
    final normalizedConfidence = (maxScore / (predictions.length * 0.8)).clamp(0.0, 0.95);

    // Top émotions
    List<String> topEmotions = sortedEmotions
      .take(3)
      .where((e) => e.value > 0.4)
      .map((e) => e.key)
      .toList();

    print('✅ Détection terminée:');
    print('  - Émotion: ${topEmotions.isNotEmpty ? topEmotions.first : "N/A"}');
    print('  - Confiance: ${(normalizedConfidence * 100).toInt()}%');
    print('  - Signaux: ${predictions.length}');
    print('  - Raisons: ${reasons.join(", ")}');

    return DetectedEmotionalState(
      primaryEmotion: topEmotions.isNotEmpty ? topEmotions.first : null,
      secondaryEmotions: topEmotions.length > 1 ? topEmotions.sublist(1) : [],
      confidence: normalizedConfidence,
      detectionReasons: reasons,
      rawPredictions: predictions,
      detectedAt: now,
    );
  }
}