// lib/services/prediction_notification_service.dart
//
// Planifie chaque jour à 19h une notification avec :
//   - Le score IRM prédit pour demain
//   - Le conseil préventif associé
//
// À appeler : au démarrage de l'app + après chaque check-in

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'prediction_service.dart';

class PredictionNotificationService {
  static const int _notifId = 2001;
  static const int _notifHour = 19;

  final FlutterLocalNotificationsPlugin _notifications;
  final PredictionService _predictionService;

  PredictionNotificationService({
    FlutterLocalNotificationsPlugin? notifications,
    PredictionService? predictionService,
  })  : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _predictionService = predictionService ?? PredictionService();

  // ─── PLANIFIER LA NOTIFICATION 19H ────────────────────────
  /// À appeler au démarrage et après chaque check-in.
  /// Calcule la prédiction J+1 et planifie la notif à 19h.
  Future<void> scheduleDailyPredictionNotif() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Calculer la prédiction
    final prediction = await _predictionService.getPredictionForTomorrow();
    if (prediction == null) return;

    // Construire le contenu
    final score = prediction.predictedScore.toStringAsFixed(0);
    final emoji = prediction.predictedScore >= 70 ? '🟢' : prediction.predictedScore >= 45 ? '🟡' : '🔴';
    final title = '$emoji Demain · Score prédit : $score/100';
    final body = prediction.preventiveAdvice ?? 'Ouvre MoodTips pour voir le détail.';

    // Heure cible : aujourd'hui à 19h, ou demain si déjà passé
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _notifHour, 0);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'moodtips_prediction',
      'Prédiction IRM',
      channelDescription: 'Prédiction quotidienne de ton score IRM pour demain',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Annuler l'ancienne avant de replanifier
    await _notifications.cancel(_notifId);

    await _notifications.zonedSchedule(
      _notifId,
      title,
      body,
      tz.TZDateTime.from(target, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('✅ Notif prédiction planifiée à ${target.hour}h pour score $score');
  }

  Future<void> cancel() => _notifications.cancel(_notifId);
}