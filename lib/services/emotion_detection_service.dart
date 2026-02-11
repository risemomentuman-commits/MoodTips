import '../models/detected_emotional_state.dart';
import '../models/health_context_data.dart';
import 'apple_health_service.dart';
import 'calendar_service.dart';

class EmotionDetectionService {
  /// Analyse holistique et détection émotion probable
  static Future<DetectedEmotionalState> detectCurrentState() async {
    print('🧠 Début détection état émotionnel...');
    
    // Récupération données
    final healthData = await AppleHealthService.getAllHealthData();
    final calendarEvents = await CalendarService.getUpcomingEvents();
    
    print('📊 Données récupérées:');
    print('  - Sommeil: ${healthData.sleep?.durationHours ?? "N/A"}h');
    print('  - Activité: ${healthData.activity?.steps ?? "N/A"} pas');
    print('  - Événements: ${calendarEvents.length}');
    
    // Analyse
    return _analyzeEmotionalState(healthData, calendarEvents);
  }

  static DetectedEmotionalState _analyzeEmotionalState(
    HealthContextData health,
    List<CalendarEventData> events,
  ) {
    List<EmotionPrediction> predictions = [];
    List<String> reasons = [];

    // ==================
    // ANALYSE SOMMEIL
    // ==================
    if (health.sleep != null) {
      final sleepHours = health.sleep!.durationHours;
      
      if (sleepHours < 6) {
        predictions.add(EmotionPrediction(
          emotion: 'fatigué',
          confidence: 0.85,
          reason: 'Sommeil court (${sleepHours.toStringAsFixed(1)}h)',
        ));
        reasons.add('💤 Sommeil: ${sleepHours.toStringAsFixed(1)}h (-${(7 - sleepHours).toStringAsFixed(1)}h)');
      } else if (sleepHours >= 7 && sleepHours <= 9) {
        predictions.add(EmotionPrediction(
          emotion: 'reposé',
          confidence: 0.70,
          reason: 'Bon sommeil (${sleepHours.toStringAsFixed(1)}h)',
        ));
        reasons.add('💤 Sommeil: ${sleepHours.toStringAsFixed(1)}h (optimal)');
      }
      
      if (health.sleep!.qualityScore < 60) {
        predictions.add(EmotionPrediction(
          emotion: 'irritable',
          confidence: 0.65,
          reason: 'Qualité sommeil faible (${health.sleep!.qualityScore}%)',
        ));
        reasons.add('😴 Qualité sommeil: ${health.sleep!.qualityScore}% (faible)');
      }
    }

    // ==================
    // ANALYSE CALENDRIER
    // ==================
    if (events.isNotEmpty) {
      final stressfulEvents = events.where((e) => e.isStressful).toList();
      
      if (stressfulEvents.isNotEmpty) {
        final nextEvent = stressfulEvents.first;
        final timeUntil = nextEvent.startTime.difference(DateTime.now());
        
        if (timeUntil.inHours < 2 && timeUntil.inMinutes > 0) {
          predictions.add(EmotionPrediction(
            emotion: 'anxieux',
            confidence: 0.75,
            reason: 'Événement important dans ${timeUntil.inHours}h${timeUntil.inMinutes % 60}min',
          ));
          reasons.add('📅 Événement: "${nextEvent.title}" dans ${timeUntil.inHours}h${timeUntil.inMinutes % 60}min');
        }
      }
      
      if (events.length >= 5) {
        predictions.add(EmotionPrediction(
          emotion: 'débordé',
          confidence: 0.70,
          reason: 'Journée chargée (${events.length} événements)',
        ));
        reasons.add('📆 Journée: ${events.length} événements planifiés');
      }
    }

    // ==================
    // ANALYSE ACTIVITÉ
    // ==================
    if (health.activity != null) {
      final steps = health.activity!.steps;
      
      if (steps < 3000) {
        predictions.add(EmotionPrediction(
          emotion: 'fatigué',
          confidence: 0.60,
          reason: 'Faible activité physique',
        ));
        reasons.add('🚶 Activité: $steps pas (-${8000 - steps} recommandés)');
      } else if (steps > 8000) {
        predictions.add(EmotionPrediction(
          emotion: 'énergique',
          confidence: 0.65,
          reason: 'Bonne activité physique',
        ));
        reasons.add('🚶 Activité: $steps pas (+${steps - 8000} bonus)');
      }
    }

    // ==================
    // AGRÉGATION
    // ==================
    if (predictions.isEmpty) {
      return DetectedEmotionalState(
        primaryEmotion: null,
        confidence: 0.0,
        detectionReasons: ['Pas assez de données connectées'],
        rawPredictions: [],
        detectedAt: DateTime.now(),
      );
    }

    // Scorer les émotions
    Map<String, double> emotionScores = {};
    for (var pred in predictions) {
      emotionScores[pred.emotion] = 
        (emotionScores[pred.emotion] ?? 0) + pred.confidence;
    }

    // Trier par score
    var sortedEmotions = emotionScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Top 2-3 émotions
    List<String> topEmotions = sortedEmotions
      .take(3)
      .where((e) => e.value > 0.5)
      .map((e) => e.key)
      .toList();

    // Confiance globale
    double globalConfidence = topEmotions.isEmpty ? 0.0 :
      sortedEmotions.first.value / predictions.length;

    print('✅ Détection terminée:');
    print('  - Émotion: ${topEmotions.isNotEmpty ? topEmotions.first : "N/A"}');
    print('  - Confiance: ${(globalConfidence * 100).toInt()}%');
    print('  - Raisons: ${reasons.length}');

    return DetectedEmotionalState(
      primaryEmotion: topEmotions.isNotEmpty ? topEmotions.first : null,
      secondaryEmotions: topEmotions.length > 1 ? topEmotions.sublist(1) : [],
      confidence: globalConfidence,
      detectionReasons: reasons,
      rawPredictions: predictions,
      detectedAt: DateTime.now(),
    );
  }
}