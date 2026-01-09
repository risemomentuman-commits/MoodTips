import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Messages variés pour éviter la lassitude
  static final List<String> _messages = [
    "Comment te sens-tu en ce moment ? 🌿",
    "Prends un instant pour toi 💙",
    "Un petit check-in ? 😊",
    "Comment va ton humeur aujourd'hui ? ✨",
    "Et toi, comment ça va ? 🍃",
    "Besoin d'un moment pour toi ? 🌊",
    "Petit point sur tes émotions ? 💚",
  ];
  
  static Future<void> initialize() async {
    // Initialiser les timezones
    tz.initializeTimeZones();
    
    // Configuration Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuration iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }
  
  static void _onNotificationTap(NotificationResponse response) {
    print('📱 Notification tappée : ${response.payload}');
    // Navigation vers MoodCheck page
  }
  
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    }
    
    if (Platform.isIOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    
    return false;
  }
  
  // ========== PROGRAMMER LES NOTIFICATIONS QUOTIDIENNES ==========
  
  static Future<void> scheduleDailyNotifications({
  int morningHour = 10,
  int morningMinute = 0,
  int afternoonHour = 14,
  int afternoonMinute = 30,
  int eveningHour = 19,
  int eveningMinute = 0,
}) async {
  await _notifications.cancelAll();
  
  final slots = [
    {'hour': morningHour, 'minute': morningMinute},
    {'hour': afternoonHour, 'minute': afternoonMinute},
    {'hour': eveningHour, 'minute': eveningMinute},
  ];
  
  for (int i = 0; i < slots.length; i++) {
    await _scheduleDailyNotification(
      id: i,
      hour: slots[i]['hour']!,
      minute: slots[i]['minute']!,
    );
  }
  
  print('✅ 3 notifications programmées');
}
    
    
  static Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
  }) async {
    final message = _messages[Random().nextInt(_messages.length)];
    
    await _notifications.zonedSchedule(
      id,
      'MoodTips 💙',
      message,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_mood_check',
          'Check-in quotidien',
          channelDescription: 'Rappels doux pour prendre soin de toi',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          enableVibration: false, // ✅ Pas de vibration = moins intrusif
          styleInformation: BigTextStyleInformation(message),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // ✅ Se répète chaque jour
    );
  }
  
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // Si l'heure est déjà passée aujourd'hui, programmer pour demain
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }
    
    return scheduledDate;
  }
  
  // ========== GESTION DES PRÉFÉRENCES ==========
  
  static Future<void> enableNotifications(bool enable) async {
    if (enable) {
      final granted = await requestPermission();
      if (granted) {
        await scheduleDailyNotifications();
      }
    } else {
      await _notifications.cancelAll();
      print('❌ Notifications désactivées');
    }
  }
  
  static Future<void> updateNotificationTimes({
    int? morningHour,
    int? afternoonHour,
    int? eveningHour,
  }) async {
    // Personnaliser les heures si l'utilisateur veut
    await scheduleDailyNotifications();
  }
}
