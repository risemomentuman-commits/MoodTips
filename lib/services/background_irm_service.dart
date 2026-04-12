// lib/services/background_irm_service.dart
//
// Calcule et sauvegarde le score IRM automatiquement chaque jour,
// même si l'utilisateur n'a pas fait son check-in.
//
// Logique :
//   • Si check-in fait aujourd'hui → ne rien faire (déjà calculé)
//   • Si pas de check-in → calculer avec health + calendrier (sans émotion)
//   • Après 3 jours sans check-in → notification de rappel (une seule fois)
//   • Après 7 jours sans check-in → notification plus insistante
//
// À appeler : au démarrage de l'app + via un background task quotidien

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/irm_calculator_v2.dart';
import '../services/health_service.dart';
import '../services/calendar_service.dart';
import '../services/user_learning_service.dart';
import '../repositories/irm_scores_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../models/user_profile_dynamic.dart';

class BackgroundIrmService {
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _notifications;

  static const int _notifReminderSoft = 2010; // 3 jours
  static const int _notifReminderStrong = 2011; // 7 jours
  static const int _softThreshold = 3;
  static const int _strongThreshold = 7;

  BackgroundIrmService({
    SupabaseClient? supabase,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  // ─── ENTRY POINT ──────────────────────────────────────────
  /// À appeler au démarrage de l'app et via background task.
  Future<void> runDailyCheck() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 1. Vérifier si check-in fait aujourd'hui
    final hasCheckin = await _hasCheckinToday(userId, today);

    // 2. Compter les jours consécutifs sans check-in
    final streak = await _countDaysWithoutCheckin(userId);

    // 3. Si pas de check-in → calculer IRM auto
    if (!hasCheckin) {
      await _computeAndSaveAutoIrm(userId, today);
    }

    // 4. Gérer les notifications de rappel
    await _handleReminderNotifications(streak, hasCheckin);

    // 5. Planifier le background check pour demain à 20h
    await _scheduleNextCheck();
  }

  // ─── CALCUL IRM SANS ÉMOTION ──────────────────────────────
  Future<void> _computeAndSaveAutoIrm(String userId, String today) async {
    try {
      print('🔄 Background IRM: calcul auto pour $today');

      final profileRepo = UserProfileRepository();
      final learning = UserLearningService();
      final repo = IrmScoresRepository();
      final now = DateTime.now();

      final profile = await profileRepo.getProfile(userId) ??
          UserProfileDynamic(userId: userId, createdAt: now, updatedAt: now);

      final realHealth = await HealthService.getAllHealthData();
      final last7Emotions = await learning.getLast7Emotions(userId);

      final sleepHours = realHealth.sleep?.durationHours ?? 7.0;
      final steps = realHealth.activity?.steps ?? 0;

      int totalEvents = 0, workEvents = 0, positiveEvents = 0;
      double meetingHours = 0, weightedImpact = 0;

      try {
        final events = await CalendarService.getTodayEvents();
        totalEvents = events.length;
        workEvents = CalendarService.countWorkEvents(events);
        positiveEvents = CalendarService.countPositiveEvents(events);
        meetingHours = CalendarService.calculateMeetingHours(events);
        weightedImpact = CalendarService.calculateWeightedImpact(events);
      } catch (_) {}

      final sources = <String>['auto_background'];
      if (realHealth.sleep != null) sources.add('apple_health');
      if (totalEvents > 0) sources.add('calendar');

      final score = IrmCalculatorV2.calculate(
        profile: profile,
        sleepHours: sleepHours,
        steps: steps,
        totalEvents: totalEvents,
        workEvents: workEvents,
        positiveEvents: positiveEvents,
        meetingHours: meetingHours,
        last7Emotions: last7Emotions,
        sources: sources,
        weightedImpact: weightedImpact,
        triggeredBy: 'auto_background',
      );

      await repo.saveScore(
        userId: userId,
        score: score,
        triggeredBy: 'auto_background',
      );

      await learning.saveDailyHealthData(
        userId: userId,
        sleepHours: sleepHours,
        sleepSource: realHealth.sleep != null ? 'health' : 'estimated',
        steps: steps,
        totalEvents: totalEvents,
        workEvents: workEvents,
        positiveEvents: positiveEvents,
      );

      print('✅ Background IRM sauvegardé: ${score.score}/100 (sans émotion)');
    } catch (e) {
      print('❌ Erreur background IRM: $e');
    }
  }

  // ─── NOTIFICATIONS DE RAPPEL ──────────────────────────────
  Future<void> _handleReminderNotifications(
    int daysWithoutCheckin,
    bool checkedInToday,
  ) async {
    // Si check-in fait → annuler les rappels en attente
    if (checkedInToday) {
      await _notifications.cancel(_notifReminderSoft);
      await _notifications.cancel(_notifReminderStrong);
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'moodtips_reminder',
      'Rappels check-in',
      channelDescription: 'Rappels pour améliorer la précision de l\'IRM',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // 3 jours sans check-in → rappel doux
    if (daysWithoutCheckin == _softThreshold) {
      await _notifications.show(
        _notifReminderSoft,
        '💛 Ton IRM continue de se calculer',
        'Ça fait $daysWithoutCheckin jours sans check-in. '
        'Sans ton ressenti émotionnel, le score est estimé à ~85% de précision. '
        'Un check-in rapide suffit !',
        details,
      );
      print('📣 Rappel doux envoyé ($daysWithoutCheckin jours sans check-in)');
    }

    // 7 jours sans check-in → rappel fort
    if (daysWithoutCheckin == _strongThreshold) {
      await _notifications.show(
        _notifReminderStrong,
        '⚠️ Prédictions moins précises sans toi',
        'Ça fait une semaine sans check-in. '
        'MoodTips continue d\'apprendre grâce à tes données de santé, '
        'mais ton ressenti émotionnel est irremplaçable pour affiner les prédictions.',
        details,
      );
      print('📣 Rappel fort envoyé ($daysWithoutCheckin jours sans check-in)');
    }
  }

  
  Future<void> _scheduleNextCheck() async {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 2, 0);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    // On planifie une notif silencieuse qui sert de "trigger"
    // (dans une vraie app, utiliser workmanager ou background_fetch)
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'moodtips_background',
        'Background IRM',
        channelDescription: 'Calcul IRM en arrière-plan',
        importance: Importance.min,
        priority: Priority.min,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        visibility: NotificationVisibility.secret,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        interruptionLevel: InterruptionLevel.passive,
      ),
    );

    await _notifications.zonedSchedule(
      2012,
      'IRM Background',
      '',
      tz.TZDateTime.from(target, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────
  Future<bool> _hasCheckinToday(String userId, String today) async {
    try {
      final response = await _supabase
          .from('mood_logs')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', '${today}T00:00:00')
          .limit(1)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Compte le nombre de jours consécutifs sans check-in (max 30)
  Future<int> _countDaysWithoutCheckin(String userId) async {
    try {
      int count = 0;
      final now = DateTime.now();

      for (int i = 1; i <= 30; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().substring(0, 10);

        final response = await _supabase
            .from('mood_logs')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', '${dateStr}T00:00:00')
            .lte('created_at', '${dateStr}T23:59:59')
            .limit(1)
            .maybeSingle();

        if (response == null) {
          count++;
        } else {
          break; // Chaîne brisée → on arrête
        }
      }

      return count;
    } catch (_) {
      return 0;
    }
  }
}