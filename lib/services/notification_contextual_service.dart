// lib/services/notification_contextual_service.dart
//
// Déclenche des alertes préventives basées sur le contexte IRM en temps réel.
// 3 types d'alertes :
//   • Matin  (07:30) : nuit courte + journée chargée
//   • Midi   (12:00) : matinée difficile + après-midi chargé
//   • Soir   (19:00) : score J < 50 + pas d'action de récupération
//
// Anti-spam : max 1 alerte / type / 24h

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/prediction.dart';
import 'prediction_service.dart';

enum AlertType { morning, noon, evening }

extension AlertTypeX on AlertType {
  String get value {
    switch (this) { case AlertType.morning: return 'morning';
                    case AlertType.noon:    return 'noon';
                    case AlertType.evening: return 'evening'; }
  }

  int get notificationId {
    switch (this) { case AlertType.morning: return 1001;
                    case AlertType.noon:    return 1002;
                    case AlertType.evening: return 1003; }
  }
}

class NotificationContextualService {
  final SupabaseClient    _supabase;
  final PredictionService _predictionService;
  final FlutterLocalNotificationsPlugin _notifications;

  // Seuils déclencheurs
  static const double _shortSleepThreshold  = 6.0;  // heures
  static const int    _heavyLoadThreshold   = 5;    // événements
  static const double _lowMorningScore      = 50.0;
  static const double _lowEveningScore      = 50.0;

  NotificationContextualService({
    SupabaseClient? supabase,
    PredictionService? predictionService,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _supabase           = supabase ?? Supabase.instance.client,
        _predictionService  = predictionService ?? PredictionService(),
        _notifications      = notifications ?? FlutterLocalNotificationsPlugin();

  // ─── INITIALISATION ───────────────────────────────────────
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission:  true,
      requestBadgePermission:  true,
      requestSoundPermission:  true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ─── PLANIFIER LES 3 ALERTES DU JOUR ─────────────────────
  /// À appeler après chaque check-in quotidien.
  Future<void> scheduleContextualAlerts({
    required double sleepHours,
    required int morningEvents,
    required int afternoonEvents,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prediction = await _predictionService.getPredictionForTomorrow();

    // ── Alerte matin ──────────────────────────────────────
    if (sleepHours < _shortSleepThreshold && morningEvents >= _heavyLoadThreshold) {
      final canSend = await _canSendAlert(userId, AlertType.morning);
      if (canSend) {
        await _scheduleNotification(
          type:    AlertType.morning,
          title:   '😴 Nuit courte + matinée chargée',
          body:    'Tu as dormi ${sleepHours.toStringAsFixed(1)}h et tu as '
                   '$morningEvents événements ce matin. Pense à prendre '
                   '5 min pour toi avant de démarrer.',
          hour:    7,
          minute:  30,
          triggerData: {
            'sleep_points':    sleepHours,
            'morning_events': morningEvents,
          },
        );
      }
    }

    // ── Alerte midi ───────────────────────────────────────
    if (afternoonEvents >= _heavyLoadThreshold) {
      // L'alerte midi est conditionnelle au score matinée
      // → elle sera envoyée seulement si le score matinée est bas
      // On programme une alerte conditionnelle via un background check
      await _scheduleMidnightCheck(
        userId:           userId,
        afternoonEvents:  afternoonEvents,
      );
    }

    // ── Alerte soir ───────────────────────────────────────
    if (prediction != null && prediction.predictedScore < _lowEveningScore) {
      final canSend = await _canSendAlert(userId, AlertType.evening);
      if (canSend) {
        await _scheduleNotification(
          type:    AlertType.evening,
          title:   '💛 Comment s\'est passée ta journée ?',
          body:    prediction.preventiveAdvice ??
                   'Pense à faire ton check-in et à choisir une action de récupération ce soir.',
          hour:    19,
          minute:  0,
          triggerData: {
            'predicted_score': prediction.predictedScore,
            'confidence':      prediction.confidence,
          },
        );
      }
    }
  }

  // ─── ÉVALUATION ALERTE MIDI (score matinée) ───────────────
  /// À appeler depuis un background task vers midi.
  Future<void> evaluateMorningScoreAndAlertIfNeeded() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final row   = await _supabase
        .from('irm_scores_timeline')
        .select('score, mental_load_points')
        .eq('user_id', userId)
        .eq('date', today)
        .maybeSingle();

    if (row == null) return;

    final score    = (row['score']          as num?)?.toDouble() ?? 100;
    final pmEvents = (row['mental_load_points']  as int?)            ?? 0;

    if (score < _lowMorningScore && pmEvents >= _heavyLoadThreshold) {
      final canSend = await _canSendAlert(userId, AlertType.noon);
      if (canSend) {
        await _sendImmediateNotification(
          type:  AlertType.noon,
          title: '🧠 Matinée difficile + après-midi chargé',
          body:  'Ton score de ce matin est de ${score.toStringAsFixed(0)}/100 '
                 'et tu as $pmEvents événements cet après-midi. '
                 'Prends une vraie pause déjeuner.',
          triggerData: {
            'morning_score':      score,
            'afternoon_events':   pmEvents,
          },
        );
      }
    }
  }

  // ─── ANTI-SPAM : vérifier si alerte envoyable ─────────────
  Future<bool> _canSendAlert(String userId, AlertType type) async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 23))
        .toIso8601String();

    final result = await _supabase
        .from('contextual_alerts_log')
        .select('id')
        .eq('user_id', userId)
        .eq('alert_type', type.value)
        .gte('sent_at', since)
        .limit(1);

    return (result as List).isEmpty;
  }

  // ─── PLANIFIER UNE NOTIFICATION ───────────────────────────
  Future<void> _scheduleNotification({
    required AlertType type,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required Map<String, dynamic> triggerData,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final now  = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'moodtips_contextual',
      'Alertes contextuelles',
      channelDescription: 'Alertes intelligentes basées sur ton IRM',
      importance: Importance.high,
      priority:   Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS:     iosDetails,
    );

    await _notifications.zonedSchedule(
      type.notificationId,
      title,
      body,
      tz.TZDateTime.from(target, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Log en base
    await _logAlert(userId, type, triggerData);
  }

  Future<void> _sendImmediateNotification({
    required AlertType type,
    required String title,
    required String body,
    required Map<String, dynamic> triggerData,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    const androidDetails = AndroidNotificationDetails(
      'moodtips_contextual',
      'Alertes contextuelles',
      importance: Importance.high,
      priority:   Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS:     DarwinNotificationDetails(),
    );

    await _notifications.show(type.notificationId, title, body, details);
    await _logAlert(userId, type, triggerData);
  }

  Future<void> _scheduleMidnightCheck({
    required String userId,
    required int afternoonEvents,
  }) async {
    // Stocke le contexte pour le background check de midi
    await _supabase.from('contextual_alerts_log').insert({
      'user_id':     userId,
      'alert_type':  'noon_pending',
      'trigger_data': {'afternoon_events': afternoonEvents},
    });
  }

  Future<void> _logAlert(
    String userId,
    AlertType type,
    Map<String, dynamic> triggerData,
  ) async {
    await _supabase.from('contextual_alerts_log').insert({
      'user_id':      userId,
      'alert_type':   type.value,
      'trigger_data': triggerData,
    });
  }

  // ─── ANNULER TOUTES LES ALERTES ───────────────────────────
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}