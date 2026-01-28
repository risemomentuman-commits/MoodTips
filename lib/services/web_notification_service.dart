// lib/services/web_notification_service.dart
// Service de notifications push Web via Firebase Cloud Messaging

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class WebNotificationService {
  static FirebaseMessaging? _messaging;
  static final supabase = Supabase.instance.client;
  
  /// Initialiser Firebase et demander la permission
  static Future<void> initialize() async {
    if (!kIsWeb) {
      print('❌ WebNotificationService: Not on web');
      return;
    }
    
    try {
      // ⚠️ REMPLACE PAR TES VRAIES VALEURS FIREBASE
      await Firebase.initializeApp(
        options: FirebaseOptions(
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
      
      print('✅ Firebase initialisé pour Web');
      
    } catch (e) {
      print('❌ Erreur initialisation Firebase: $e');
    }
  }
  
  /// Demander la permission pour les notifications
  static Future<bool> requestPermission() async {
    if (!kIsWeb || _messaging == null) return false;
    
    try {
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
      
      if (granted) {
        print('✅ Permission notifications accordée');
        await _getAndSaveToken();
      } else {
        print('❌ Permission notifications refusée');
      }
      
      return granted;
      
    } catch (e) {
      print('❌ Erreur demande permission: $e');
      return false;
    }
  }
  
  /// Récupérer le token FCM et le sauvegarder en DB
  static Future<void> _getAndSaveToken() async {
    try {
      // ⚠️ REMPLACE PAR TA VRAIE VAPID KEY
      final token = await _messaging!.getToken(
        vapidKey: "BJcHGTpf3Rauw9tepfVU6KD2GoLHhqLSiM9k02STWJe07o0o0Y0L6fJK5BazxXC2aq2cWVpt9vWfUWVNoi1uhJk",
      );
      
      if (token == null) {
        print('❌ TOKEN NULL - Firebase a échoué');
        return;
      } else {
        print('✅✅✅ TOKEN REÇU: $token');
      }
      
      print('✅ Token FCM: ${token.substring(0, 20)}...');
      
      // Sauvegarder en base de données
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ User non connecté');
        return;
      }
      
      await supabase
        .from('profiles')
        .update({
          'fcm_token': token,
          'notifications_enabled': true,
        })
        .eq('id', userId);
      
      print('✅ Token sauvegardé en DB');
      
      // Écouter le refresh du token
      _messaging!.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });
      
    } catch (e) {
      print('❌ Erreur get token: $e');
    }
  }
  
  /// Sauvegarder le token en DB
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await supabase
        .from('profiles')
        .update({'fcm_token': token})
        .eq('id', userId);
        
      print('✅ Token mis à jour en DB');
      
    } catch (e) {
      print('❌ Erreur save token: $e');
    }
  }
  
  /// Activer/désactiver les notifications
  static Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      if (enabled) {
        // Activer : demander permission et récupérer token
        final granted = await requestPermission();
        if (!granted) {
          print('❌ Permission refusée');
          return;
        }
        // Le token est sauvegardé automatiquement dans requestPermission()
      } else {
        // Désactiver : juste mettre le flag à false
        await supabase
          .from('profiles')
          .update({'notifications_enabled': false})
          .eq('id', userId);
        
        print('✅ Notifications désactivées');
      }
      
    } catch (e) {
      print('❌ Erreur setNotificationsEnabled: $e');
    }
  }
  /// Récupérer l'état des notifications
  static Future<bool> areNotificationsEnabled() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      final response = await supabase
        .from('profiles')
        .select('notifications_enabled')
        .eq('id', userId)
        .single();
      
      return response['notifications_enabled'] ?? false;
      
    } catch (e) {
      print('❌ Erreur areNotificationsEnabled: $e');
      return false;
    }
  }
  
  /// Setup des listeners pour les messages
  static void setupListeners() {
    if (!kIsWeb || _messaging == null) return;
    
    // Messages reçus quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Message reçu (app active): ${message.notification?.title}');
      
      // Tu peux afficher une notif in-app ici si tu veux
    });
    
    // Messages reçus quand on click sur la notif
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Notif cliquée: ${message.notification?.title}');
      
      // Navigation vers la bonne page si besoin
    });
  }
}