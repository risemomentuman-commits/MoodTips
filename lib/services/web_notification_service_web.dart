// lib/services/web_notification_service.dart
// Notifications push Web via Firebase Cloud Messaging (FCM) + Supabase

// ✅ Export conditionnel
export 'web_notification_service_web.dart' 
  if (dart.library.io) 'web_notification_service_stub.dart';

import 'dart:html' as html;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fcm_web_js.dart';



class WebNotificationService {
  static FirebaseMessaging? _messaging;
  static final supabase = Supabase.instance.client;

  // ⚠️ Mets ici TA VAPID Key (Firebase Console -> Cloud Messaging -> Web Push certificates)
  static const String _vapidKey =
      "BJcHGTpf3Rauw9tepfVU6KD2GoLHhqLSiM9k02STWJe07o0o0Y0L6fJK5BazxXC2aq2cWVpt9vWfUWVNoi1uhJk"; // ex: "BJcHGTp..."

  // LocalStorage key (pour stocker le token si user pas connecté)
  static const String _lsPendingTokenKey = "pending_fcm_token";

  // web only
  static const _localEnabledKey = 'notifications_enabled_web';

  static void setLocalEnabled(bool value) {
    html.window.localStorage[_localEnabledKey] = value.toString();
  }

  static bool getLocalEnabled() {
    return html.window.localStorage[_localEnabledKey] == 'true';
  }


  /// 1) Initialise Firebase (Web only) + prépare FCM
  static Future<void> initialize() async {
    print('🚀 [FCM] WebNotificationService.initialize() called');

    if (!kIsWeb) {
      print('❌ [FCM] Not on web -> skip');
      return;
    }

    try {
      // IMPORTANT: ne pas mettre ces clés en public si tu peux éviter
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCSdZQtz9blpwpXx54EQ4mHudmcGs66QjA",
          authDomain: "moodtips-f2f0b.firebaseapp.com",
          projectId: "moodtips-f2f0b",
          storageBucket: "moodtips-f2f0b.firebasestorage.app",
          messagingSenderId: "988485491350",
          appId: "1:988485491350:web:27d494da0d1f32553480b7",
          measurementId: "G-Y1QG0N5B52"
        ),
      );

      _messaging = FirebaseMessaging.instance;

      // (Optionnel) Réduit les surprises: auto-init FCM
      await _messaging!.setAutoInitEnabled(true);

      print('✅ [FCM] Firebase initialized for Web');

      // Setup listeners (n’affecte pas la génération du token)
      setupListeners();

      // Si un token était en attente (user pas connecté), tente de sync
      await syncPendingTokenIfAny();

    } catch (e) {
      print('❌ [FCM] Firebase initialize error: $e');
    }
  }

  /// 2) Demande la permission navigateur et récupère le token
  static Future<bool> requestPermissionAndRegisterToken() async {
    print('🚀 [FCM] requestPermissionAndRegisterToken() called');

    if (!kIsWeb || _messaging == null) {
      print('❌ [FCM] Not ready (web=$kIsWeb, messaging=${_messaging != null})');
      return false;
    }

    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('🔔 Permission: ${settings.authorizationStatus}');
      // web-only: état permission navigateur
      print('🔔 Browser Notification.permission: ${html.Notification.permission}');

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (!granted) {
        print('❌ [FCM] Permission denied or not authorized.');
        return false;
      }

      await _getAndStoreToken(); // ou _getAndSaveToken() selon ton nom
      return true;
    } catch (e) {
      print('❌ [FCM] Permission request error: $e');
      return false;
    }
  }


  /// 3) Récupère le token FCM (Web) et l’enregistre
  static Future<void> _getAndStoreToken() async {
    if (!kIsWeb || _messaging == null) return;

    if (_vapidKey.startsWith("REMPLACE_")) {
      print('❌ [FCM] VAPID KEY missing. Set _vapidKey first.');
      return;
    }

    try {
      // ✅ IMPORTANT: forcer Firebase à utiliser le SW du sous-dossier /MoodTips/
      final sw = html.window.navigator.serviceWorker;
      final registration = await sw?.getRegistration('/MoodTips/');

      if (registration == null) {
        print('❌ [FCM] No SW registration found for /MoodTips/');
        await _debugServiceWorkerState();
        return;
      }

      print('✅ [FCM] Using SW registration scope: ${registration.scope}');

      final token = await getFcmTokenFromWebJs(_vapidKey);

      if (token == null) {
        print('❌ [FCM] Token is NULL (getToken failed).');
        await _debugServiceWorkerState();
        return;
      }

      print('✅ [FCM] TOKEN RECEIVED: ${token.substring(0, 20)}...');

      // Sauvegarde immédiate en DB si user connecté
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ [FCM] User not logged in. Storing token in localStorage.');
        _storePendingToken(token);
        return;
      }

      await _saveTokenToDatabase(token, userId: userId);

      // Écouter refresh token
      _messaging!.onTokenRefresh.listen((newToken) async {
        print('🔁 [FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        final uid = supabase.auth.currentUser?.id;
        if (uid != null) {
          await _saveTokenToDatabase(newToken, userId: uid);
        } else {
          _storePendingToken(newToken);
        }
      });
    } catch (e) {
      print('❌ [FCM] getToken error: $e');
      await _debugServiceWorkerState();
    }
  }


  /// 4) Sauvegarde DB Supabase
  static Future<void> _saveTokenToDatabase(String token, {required String userId}) async {
    try {
      await supabase.from('profiles').update({
        'fcm_token': token,
        'push_notifications_enabled': true,
      }).eq('id', userId);
      print('✅ [DB] push_notifications_enabled set to TRUE for user=$userId');


      print('✅ [FCM] Token saved to DB for user=$userId');
    } catch (e) {
      print('❌ [FCM] DB save error: $e');
      // conserve aussi en local au cas où
      _storePendingToken(token);
    }
  }

  /// 5) Active / désactive les notifications côté DB
  static Future<void> setNotificationsEnabled(bool enabled) async {
    if (!kIsWeb) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      print('⚠️ [FCM] setNotificationsEnabled: user not logged in');
      if (enabled) {
        // on peut quand même demander la permission et obtenir le token
        await requestPermissionAndRegisterToken();
      }
      return;
    }

    try {
      if (enabled) {
        final granted = await requestPermissionAndRegisterToken();
        if (!granted) return;
        // La DB sera mise à jour dans _saveTokenToDatabase
      } else {
        await supabase.from('profiles').update({
          'push_notifications_enabled': false,
        }).eq('id', userId);

        print('✅ [FCM] Notifications disabled in DB');
      }
    } catch (e) {
      print('❌ [FCM] setNotificationsEnabled error: $e');
    }
  }

  /// 6) Lire l’état des notifs depuis DB
  static Future<bool> areNotificationsEnabled() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final row = await supabase
          .from('profiles')
          .select('push_notifications_enabled')
          .eq('id', userId)
          .single();

      return (row['push_notifications_enabled'] ?? false) as bool;
    } catch (e) {
      print('❌ [FCM] areNotificationsEnabled error: $e');
      return false;
    }
  }

  /// 7) Listeners FCM (foreground + click)
  static void setupListeners() {
    if (!kIsWeb || _messaging == null) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 [FCM] Foreground message: ${message.notification?.title}');
      // Ici tu peux afficher un toast/in-app banner si tu veux
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🖱️ [FCM] Notification clicked: ${message.notification?.title}');
      // Ici tu peux router vers une page spécifique
    });
  }

  /// 8) Stocke token en attente (user pas connecté)
  static void _storePendingToken(String token) {
    try {
      html.window.localStorage[_lsPendingTokenKey] = token;
      print('🧾 [FCM] Token stored in localStorage as pending.');
    } catch (e) {
      print('❌ [FCM] localStorage write error: $e');
    }
  }

  /// 9) Sync token pending si user vient de se connecter
  static Future<void> syncPendingTokenIfAny() async {
    if (!kIsWeb) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final pending = html.window.localStorage[_lsPendingTokenKey];
      if (pending == null || pending.isEmpty) return;

      print('🔄 [FCM] Syncing pending token to DB...');
      await _saveTokenToDatabase(pending, userId: userId);

      html.window.localStorage.remove(_lsPendingTokenKey);
      print('✅ [FCM] Pending token synced and cleared.');
    } catch (e) {
      print('❌ [FCM] syncPendingTokenIfAny error: $e');
    }
  }

  /// 10) Debug service worker registration (utile si token null)
  static Future<void> _debugServiceWorkerState() async {
    if (!kIsWeb) return;
    try {
      final regs = await html.window.navigator.serviceWorker?.getRegistrations();
      print('🛠️ [FCM] SW registrations count: ${regs?.length ?? 0}');
      if (regs != null) {
        for (final r in regs) {
          print('🛠️ [FCM] SW scope: ${r.scope}');
        }
      }
    } catch (e) {
      print('❌ [FCM] SW debug error: $e');
    }
  }
}
