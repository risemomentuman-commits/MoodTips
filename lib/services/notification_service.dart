import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show GlobalKey, NavigatorState, Color;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> initialize() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    
    final paris = tz.getLocation('Europe/Paris');
    tz.setLocalLocation(paris);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );

    try {
      await _notifications.initialize(
        InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: (response) {
          navigatorKey?.currentState?.pushNamed('/moodCheck');
        },
      );
      print('✅ NotificationService initialisé');
    } catch (e) {
      print('⚠️ NotificationService init failed: $e');
    }
  }

  /// Notification contextuelle : 3j sans check-in ou IRM rouge 2j de suite
  static Future<void> checkAndSendContextualNotification() async {
    if (kIsWeb) return;
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final supabase = Supabase.instance.client;

      // 1. Vérifier dernière notif contextuelle (éviter spam)
      final profile = await supabase
          .from('profiles')
          .select('last_contextual_notif, notifications_enabled')
          .eq('id', userId)
          .single();

      if (!(profile['notifications_enabled'] ?? false)) return;

      final lastNotif = profile['last_contextual_notif'];
      if (lastNotif != null) {
        final diff = DateTime.now().difference(DateTime.parse(lastNotif));
        if (diff.inDays < 3) return; // Max 1 notif contextuelle / 3 jours
      }

      // 2. Vérifier dernière check-in
      final lastLog = await supabase
          .from('mood_logs')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      bool shouldNotify = false;
      String title = '';
      String body = '';

      if (lastLog == null) {
        shouldNotify = true;
        title = 'MoodTips te pense 🌿';
        body = 'Le mode standard prend 2 minutes. Comment vas-tu aujourd\'hui ?';
      } else {
        final lastCheckIn = DateTime.parse(lastLog['created_at']);
        final daysSince = DateTime.now().difference(lastCheckIn).inDays;

        if (daysSince >= 3) {
          shouldNotify = true;
          title = 'Tu nous manques 💙';
          body = 'Pas de check-in depuis $daysSince jours. Le mode standard est là pour toi.';
        }
      }

      // 3. Vérifier IRM rouge 2j de suite
      if (!shouldNotify) {
        final irmHistory = await supabase
            .from('irm_scores_timeline')
            .select('score, date')
            .eq('user_id', userId)
            .order('date', ascending: false)
            .limit(2);

        if (irmHistory.length >= 2) {
          final bothRed = irmHistory.every((e) => (e['score'] as num?)?.toDouble() != null && (e['score'] as num).toDouble() < 40);
          if (bothRed) {
            shouldNotify = true;
            title = 'MoodTips est là pour toi 🔴';
            body = 'Ton IRM est en zone rouge depuis 2 jours. Un check-in rapide peut t\'aider.';
          }
        }
      }

      if (!shouldNotify) return;

      // 4. Envoyer la notification
      await _notifications.show(
        98,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'contextual',
            'Rappels contextuels',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: false,
            color: Color(0xFFE8875A),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: 'contextual',
      );

      // 5. Sauvegarder date dernière notif
      await supabase
          .from('profiles')
          .update({'last_contextual_notif': DateTime.now().toIso8601String()})
          .eq('id', userId);

      print('🔔 Notification contextuelle envoyée: $title');
    } catch (e) {
      print('❌ Erreur notif contextuelle: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isIOS) {
        final plugin = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('🔔 Permission iOS: $granted');
        return granted ?? false;
      }
      if (Platform.isAndroid) {
        final plugin = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.requestNotificationsPermission();
        print('🔔 Permission Android: $granted');
        return granted ?? false;
      }
    } catch (e) {
      print('❌ Erreur permission: $e');
    }
    return false;
  }

  /// ✅ 2 notifications IRM par jour
  static Future<void> scheduleIRMNotifications() async {
    if (kIsWeb) return;
    try {
      await _notifications.cancelAll();
    } catch (e) {
      print('⚠️ cancelAll failed: $e');
    }

    await _scheduleDaily(
      id: 1,
      hour: 8,
      minute: 0,
      title: 'MoodTips · Fais ton check-in quotidien 🌅',
      body: 'Fais ton check-in quotidien pour que MoodTips apprenne à te connaître 💡',
    );


    print('✅ 1 notification IRM programmée (8h)');
  }

  /// Alias pour compatibilité
  static Future<void> scheduleDailyNotifications() => scheduleIRMNotifications();
  static Future<void> cancelAllNotifications() => cancelAll();

  /// Notification IRM immédiate (alerte zone rouge/orange)
  static Future<void> sendIRMAlert({
    required int score,
    required String message,
  }) async {
    if (kIsWeb) return;
    await _notifications.show(
      99,
      'MoodTips · Alerte IRM',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'irm_alerts',
          'Alertes IRM',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: Color(0xFFE8875A),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: 'irm_alert',
    );
    print('🔔 Notification IRM envoyée: $score/100');
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        _nextInstance(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'irm_daily',
            'Bilan IRM quotidien',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: false,
            color: Color(0xFFE8875A),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('🔔 Programmée: ${hour}h${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      print('⚠️ Notification $id scheduling failed: $e');
    }
  }

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final paris = tz.getLocation('Europe/Paris');
    final now = tz.TZDateTime.now(paris);
    var scheduled = tz.TZDateTime(paris, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
    print('❌ Notifications annulées');
  }
}