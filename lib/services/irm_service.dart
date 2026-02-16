import 'package:supabase_flutter/supabase_flutter.dart';
import 'health_service.dart';
import 'calendar_service.dart';
import '../models/health_context_data.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ==========================================
// MODÈLES IRM
// ==========================================

enum IRMZone { stable, pressure, danger }

class IRMFactor {
  final String label;
  final String emoji;
  final int impact; // négatif ou positif
  final String description;

  const IRMFactor({
    required this.label,
    required this.emoji,
    required this.impact,
    required this.description,
  });
}

class IRMResult {
  final int score;
  final IRMZone zone;
  final List<IRMFactor> factors;
  final IRMFactor? topFactor; // facteur principal du jour
  final String recommendation;
  final String protocol;
  final String notificationMessage;
  final SleepDataSource sleepSource;
  final DateTime calculatedAt;

  const IRMResult({
    required this.score,
    required this.zone,
    required this.factors,
    this.topFactor,
    required this.recommendation,
    required this.protocol,
    required this.notificationMessage,
    required this.sleepSource,
    required this.calculatedAt,
  });

  String get zoneEmoji {
    switch (zone) {
      case IRMZone.stable: return '🔵';
      case IRMZone.pressure: return '🟠';
      case IRMZone.danger: return '🔴';
    }
  }

  String get zoneLabel {
    switch (zone) {
      case IRMZone.stable: return 'Zone Stable';
      case IRMZone.pressure: return 'Sous Pression';
      case IRMZone.danger: return 'Zone Rouge';
    }
  }

  String get zoneDescription {
    switch (zone) {
      case IRMZone.stable: return 'Ton équilibre mental est bon aujourd\'hui.';
      case IRMZone.pressure: return 'Quelques facteurs de stress détectés. Reste vigilant.';
      case IRMZone.danger: return 'Risque élevé de surcharge. Un protocole de récupération s\'impose.';
    }
  }
}

enum SleepDataSource { measured, estimated, unknown }

// ==========================================
// IRM SERVICE
// ==========================================

class IRMService {

  /// Envoie une notification IRM si zone orange ou rouge
  static Future<void> sendIRMNotification(IRMResult result) async {
    if (kIsWeb) return;
    if (result.zone == IRMZone.stable) return; // Pas de notif si tout va bien

    await NotificationService.sendIRMAlert(
      score: result.score,
      message: result.notificationMessage,
    );
  }

  /// Calcule le score IRM complet
  static Future<IRMResult> calculateScore({
    double? estimatedSleepHours, // si l'utilisateur a saisi manuellement
  }) async {
    print('🧮 Calcul IRM...');

    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;
    final isWeekend = dayOfWeek >= 6;
    final isEvening = hour >= 18;

    // Récupération données
    final healthData = await HealthService.getAllHealthData();
    final calendarEvents = await CalendarService.getUpcomingEvents();
    final moodHistory = await _getRecentMoodHistory();

    List<IRMFactor> factors = [];
    int score = 100;

    // ==========================================
    // 1. SOMMEIL
    // ==========================================
    SleepDataSource sleepSource = SleepDataSource.unknown;
    double? sleepHours;

    if (healthData.sleep != null) {
      sleepHours = healthData.sleep!.durationHours;
      sleepSource = SleepDataSource.measured;
    } else if (estimatedSleepHours != null) {
      sleepHours = estimatedSleepHours;
      sleepSource = SleepDataSource.estimated;
    }

    if (sleepHours != null) {
      if (sleepHours < 5) {
        score -= 25;
        factors.add(IRMFactor(
          label: 'Nuit très courte',
          emoji: '😮‍💨',
          impact: -25,
          description: '${sleepHours.toStringAsFixed(1)}h de sommeil (min recommandé: 7h)',
        ));
      } else if (sleepHours < 6) {
        score -= 15;
        factors.add(IRMFactor(
          label: 'Sommeil insuffisant',
          emoji: '😴',
          impact: -15,
          description: '${sleepHours.toStringAsFixed(1)}h de sommeil (-${(7 - sleepHours).toStringAsFixed(1)}h)',
        ));
      } else if (sleepHours < 7) {
        score -= 8;
        factors.add(IRMFactor(
          label: 'Sommeil correct',
          emoji: '💤',
          impact: -8,
          description: '${sleepHours.toStringAsFixed(1)}h de sommeil (légèrement insuffisant)',
        ));
      } else if (sleepHours >= 7 && sleepHours <= 9) {
        factors.add(IRMFactor(
          label: 'Sommeil optimal',
          emoji: '✨',
          impact: 0,
          description: '${sleepHours.toStringAsFixed(1)}h de sommeil (optimal)',
        ));
      }

      // Dette de sommeil 7 jours
      final sleepDebt = await _calculateSleepDebt7Days();
      if (sleepDebt > 5) {
        score -= 10;
        factors.add(IRMFactor(
          label: 'Dette de sommeil',
          emoji: '🛌',
          impact: -10,
          description: '${sleepDebt.toStringAsFixed(1)}h de dette sur 7 jours',
        ));
      }
    } else {
      // Données inconnues → pénalité légère, les autres signaux compensent
      score -= 5;
      sleepSource = SleepDataSource.unknown;
      print('⚠️ Sommeil inconnu - pondération réduite');
    }

    // ==========================================
    // 2. ACTIVITÉ PHYSIQUE (contextualisée)
    // ==========================================
    if (healthData.activity != null) {
      final steps = healthData.activity!.steps;

      if (isEvening) {
        // Soir : évaluation de la journée complète
        if (steps < 3000) {
          score -= 15;
          factors.add(IRMFactor(
            label: 'Journée sédentaire',
            emoji: '🪑',
            impact: -15,
            description: '$steps pas aujourd\'hui (objectif: 8000)',
          ));
        } else if (steps < 6000) {
          score -= 8;
          factors.add(IRMFactor(
            label: 'Activité modérée',
            emoji: '🚶',
            impact: -8,
            description: '$steps pas aujourd\'hui',
          ));
        } else if (steps >= 8000) {
          score += 5;
          factors.add(IRMFactor(
            label: 'Objectif atteint',
            emoji: '🏃',
            impact: 5,
            description: '$steps pas — excellent !',
          ));
        }
      }
      // Matin : pas d'évaluation activité (journée pas commencée)
    }

    // ==========================================
    // 3. CHARGE AGENDA
    // ==========================================
    if (calendarEvents.isNotEmpty) {
      final todayEvents = calendarEvents.where((e) {
        final d = e.startTime;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      final stressfulEvents = todayEvents.where((e) => e.isStressful).toList();

      if (todayEvents.length >= 6) {
        score -= 15;
        factors.add(IRMFactor(
          label: 'Journée très chargée',
          emoji: '📆',
          impact: -15,
          description: '${todayEvents.length} événements planifiés',
        ));
      } else if (todayEvents.length >= 4) {
        score -= 8;
        factors.add(IRMFactor(
          label: 'Agenda dense',
          emoji: '📅',
          impact: -8,
          description: '${todayEvents.length} événements aujourd\'hui',
        ));
      }

      if (stressfulEvents.isNotEmpty) {
        final nextStressful = stressfulEvents.first;
        final timeUntil = nextStressful.startTime.difference(now);

        if (timeUntil.inHours < 4 && timeUntil.inMinutes > 0) {
          score -= 10;
          factors.add(IRMFactor(
            label: 'Événement clé imminent',
            emoji: '⚡',
            impact: -10,
            description: '"${nextStressful.title}" dans ${timeUntil.inHours}h${timeUntil.inMinutes % 60}min',
          ));
        }
      }

      // Weekend sans événements = bonus
      if (isWeekend && todayEvents.isEmpty) {
        score += 10;
        factors.add(IRMFactor(
          label: 'Weekend libre',
          emoji: '🎉',
          impact: 10,
          description: 'Aucune contrainte planifiée',
        ));
      }
    }

    // ==========================================
    // 4. HISTORIQUE HUMEUR 7 JOURS
    // ==========================================
    if (moodHistory.isNotEmpty) {
      final negativeEmotions = ['fatigué', 'anxieux', 'triste', 'stressé', 'épuisé', 'irritable', 'débordé'];
      final recentNegative = moodHistory.take(5).where((log) {
        final name = log['emotions']?['name']?.toString().toLowerCase() ?? '';
        return negativeEmotions.any((neg) => name.contains(neg));
      }).length;

      if (recentNegative >= 4) {
        score -= 15;
        factors.add(IRMFactor(
          label: 'Tendance négative',
          emoji: '📊',
          impact: -15,
          description: '$recentNegative humeurs difficiles sur 5 jours',
        ));
      } else if (recentNegative >= 3) {
        score -= 8;
        factors.add(IRMFactor(
          label: 'Quelques jours difficiles',
          emoji: '📊',
          impact: -8,
          description: '$recentNegative humeurs difficiles récemment',
        ));
      } else if (recentNegative == 0 && moodHistory.length >= 3) {
        score += 5;
        factors.add(IRMFactor(
          label: 'Humeur stable',
          emoji: '😊',
          impact: 5,
          description: 'Bonne régularité émotionnelle cette semaine',
        ));
      }
    }

    // ==========================================
    // 5. CONTEXTE TEMPOREL
    // ==========================================
    if (isWeekend) {
      score += 10;
    } else if (dayOfWeek == 5 && isEvening) {
      score += 5;
      factors.add(IRMFactor(
        label: 'Vendredi soir',
        emoji: '🎊',
        impact: 5,
        description: 'Weekend qui commence !',
      ));
    }

    // ==========================================
    // 6. NORMALISATION + ZONE
    // ==========================================
    score = score.clamp(0, 100);

    final zone = score >= 70
        ? IRMZone.stable
        : score >= 40
            ? IRMZone.pressure
            : IRMZone.danger;

    // Facteur principal (impact le plus négatif)
    final negativeFactors = factors.where((f) => f.impact < 0).toList();
    negativeFactors.sort((a, b) => a.impact.compareTo(b.impact));
    final topFactor = negativeFactors.isNotEmpty ? negativeFactors.first : null;

    // Recommandation + Protocole selon zone
    final recommendation = _getRecommendation(zone, topFactor);
    final protocol = _getProtocol(zone, topFactor);
    final notifMessage = _getNotificationMessage(score, zone, topFactor);

    print('✅ IRM calculé: $score/100 → ${zone.name}');
    print('   Facteurs: ${factors.length}');

    // Sauvegarde en base
    await _saveIRMScore(score, zone, factors);

    return IRMResult(
      score: score,
      zone: zone,
      factors: factors,
      topFactor: topFactor,
      recommendation: recommendation,
      protocol: protocol,
      notificationMessage: notifMessage,
      sleepSource: sleepSource,
      calculatedAt: now,
    );
  }

  // ==========================================
  // RECOMMANDATIONS PAR ZONE
  // ==========================================

  static String _getRecommendation(IRMZone zone, IRMFactor? topFactor) {
    switch (zone) {
      case IRMZone.stable:
        return 'Ton équilibre est bon. Profite de cette énergie pour avancer sur tes priorités.';
      case IRMZone.pressure:
        if (topFactor?.label.contains('sommeil') == true || topFactor?.label.contains('Sommeil') == true) {
          return 'La fatigue peut réduire ta concentration. Planifie une micro-pause dans la journée.';
        } else if (topFactor?.label.contains('Agenda') == true || topFactor?.label.contains('chargée') == true) {
          return 'Journée dense détectée. Priorise tes 3 tâches essentielles et protège tes pauses.';
        }
        return 'Quelques signaux de pression détectés. Un protocole court peut tout changer.';
      case IRMZone.danger:
        return 'Risque élevé de surcharge cognitive. Ton corps et ton esprit ont besoin de récupération maintenant.';
    }
  }

  static String _getProtocol(IRMZone zone, IRMFactor? topFactor) {
    switch (zone) {
      case IRMZone.stable:
        return '✨ Maintiens ton rythme · Hydrate-toi · 1 moment de pleine conscience';
      case IRMZone.pressure:
        return '🫁 Reset nerveux 3 min · Marche 10 min · Pause sans écran à midi';
      case IRMZone.danger:
        return '🚨 Respiration 4-7-8 maintenant · Sieste 10 min · Annule le non-essentiel';
    }
  }

  static String _getNotificationMessage(int score, IRMZone zone, IRMFactor? topFactor) {
    final zoneEmoji = zone == IRMZone.stable ? '🔵' : zone == IRMZone.pressure ? '🟠' : '🔴';
    final factorText = topFactor != null ? ' · ${topFactor.description}' : '';

    switch (zone) {
      case IRMZone.stable:
        return '$zoneEmoji Score IRM $score/100 — Bonne journée en vue !';
      case IRMZone.pressure:
        return '$zoneEmoji Score IRM $score/100$factorText · Reset nerveux recommandé.';
      case IRMZone.danger:
        return '$zoneEmoji Zone rouge ($score/100)$factorText · Protocole de récupération urgent.';
    }
  }

  // ==========================================
  // DETTE DE SOMMEIL 7 JOURS
  // ==========================================

  static Future<double> _calculateSleepDebt7Days() async {
    // TODO: implémenter avec historique Apple Health sur 7 jours
    // Pour l'instant retourne 0
    return 0.0;
  }

  // ==========================================
  // HISTORIQUE HUMEUR
  // ==========================================

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
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur historique IRM: $e');
      return [];
    }
  }

  // ==========================================
  // SAUVEGARDE SUPABASE
  // ==========================================

  static Future<void> _saveIRMScore(int score, IRMZone zone, List<IRMFactor> factors) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('irm_scores').upsert(
        {
          'user_id': userId,
          'score': score,
          'zone': zone.name,
          'factors_count': factors.length,
          'calculated_at': DateTime.now().toIso8601String(),
          'date': DateTime.now().toIso8601String().substring(0, 10),
        },
        onConflict: 'user_id,date',
      );
    } catch (e) {
      print('❌ Erreur sauvegarde IRM: $e');
    }
  }
}