import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'utils/app_routes.dart';
import 'utils/app_colors.dart';
import 'pages/auth_page.dart';
import 'pages/mood_check_page.dart';
import 'pages/onboarding_slides_page.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/audio_preloader.dart';
import 'pages/welcome_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pages/badges_page.dart';
import 'services/dashboard_cache.dart'; 
import 'services/supabase_service.dart';
import 'models/user_profile.dart';
import 'models/mood_log.dart';
import 'services/google_tts_service.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';
import '../services/consent_service.dart';
import '../pages/consent_page.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio_background/just_audio_background.dart'; // ← ajoute en haut



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Supabase
  await Supabase.initialize(
    url: 'https://bfyehaltboxxsivqtfhq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmeWVoYWx0Ym94eHNpdnF0ZmhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4NjMzMzEsImV4cCI6MjA4MjQzOTMzMX0.bxiMKHrjRFcIfqcoE7oj6lTlFVjcs-FnP6Mq69eWmdc',
  );
  // Initialiser Firebase Web (seulement sur Web)
  if (kIsWeb) {
   
  }

 
  AudioPreloader.preloadAudio();
  
  // ✅ Initialiser les notifications
  if (!kIsWeb) {
    try {
      await NotificationService.initialize();
    } catch (e) {
      print('⚠️ Notifications init failed: $e');
    }
  }

  if (!kIsWeb) await GoogleTTSService.initialize();
  
  if (!kIsWeb) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.moodtips.audio',
        androidNotificationChannelName: 'MoodTips Audio',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      print('⚠️ JustAudioBackground init failed: $e');
    }
  }

  await AppColors.loadTheme();

  _preloadDashboardData();
  
  NotificationService.navigatorKey = navigatorKey;
  runApp(MyApp(navigatorKey: navigatorKey));
}
// ✅ AJOUTER cette fonction
void _preloadDashboardData() async {
    try {
      print('📊 Préchargement dashboard...');
      
      // Vérifier si user connecté
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('❌ Pas d\'utilisateur connecté, skip preload');
        return;
      }
      
      // Charger en parallèle
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getMoodLogs(limit: 7),
        SupabaseService.getContextInsights(),
        _preloadExerciseStats(),
      ]);
      
      // Sauvegarder dans le cache
      DashboardCache.update(
        newProfile: results[0] as UserProfile?,
        newMoods: results[1] as List<MoodLog>,
        newContexts: results[2] as Map<String, dynamic>?,
        newStats: results[3] as Map<String, dynamic>?,
      );
      
      print('✅ Dashboard préchargé !');
    } catch (e) {
      print('❌ Erreur préchargement dashboard: $e');
      // Pas grave, le dashboard chargera normalement
    }
  }

  // ✅ AJOUTER cette fonction aussi
  Future<Map<String, dynamic>?> _preloadExerciseStats() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
      
      final response = await Supabase.instance.client
          .from('tips_sessions')
          .select('duration_actual_seconds, tips(category)')
          .eq('user_id', userId)
          .eq('completed', true)
          .gte('completed_at', oneWeekAgo.toIso8601String());

      int breathing = 0, movement = 0, mental = 0;
      int totalSeconds = 0;
      
      for (var item in response as List) {
        final category = item['tips']?['category'];
        final duration = item['duration_actual_seconds'] ?? 0;
        
        if (category == 'respiration') breathing++;
        if (category == 'mouvement') movement++;
        if (category == 'mental') mental++;
        
        totalSeconds += duration as int;
      }

      return {
        'breathing': breathing,
        'movement': movement,
        'mental': mental,
        'total_minutes': (totalSeconds / 60).round(),
      };
    } catch (e) {
      print('❌ Erreur preload exercise stats: $e');
      return null;
    }
  }

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MyApp({required this.navigatorKey});

  // 🔑 Clé globale pour recharger l'app
  static final GlobalKey<_MyAppState> appKey = GlobalKey<_MyAppState>();

  // 📱 Méthode statique pour recharger toute l'app
  static void reload() {
    appKey.currentState?.reload();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Écouter les événements d'authentification
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Navigation vers reset password
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ResetPasswordPage()),
            (route) => false,
          );
        });
      }
    });
  }
  // 🔄 Méthode pour forcer le rebuild
  void reload() {
    setState(() {
      // Le setState force la reconstruction de tout le widget tree
    });
  }
  @override
  Widget build(BuildContext context) {
    return AudioServiceWidget(
      child: MaterialApp(
        navigatorKey: widget.navigatorKey,
        title: 'MoodTips',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.backgroundPrimary,
          fontFamily: 'SF Pro',
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            backgroundColor: AppColors.backgroundPrimary,
            iconTheme: IconThemeData(color: AppColors.textDark),
            titleTextStyle: TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
        
        // ✅ LOGIQUE DE ROUTING INTELLIGENTE
        home: FutureBuilder<AppStartDestination>(
          future: _determineStartDestination(),
          builder: (context, snapshot) {
            // Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: AppColors.backgroundPrimary,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              );
            }
            
            // Erreur
            if (snapshot.hasError) {
              print('Erreur routing: ${snapshot.error}');
              return AuthPage();
            }
            
            // Routing selon destination
            final destination = snapshot.data ?? AppStartDestination.auth;
            
            switch (destination) {
              case AppStartDestination.auth:
                return AuthPage();
              case AppStartDestination.onboarding:
                return OnboardingSlidesPage();
              case AppStartDestination.consent:          // ← NOUVEAU
                return ConsentPage();   
              case AppStartDestination.home:
                return MoodCheckPage(key: MoodCheckPage.pageKey);
            }
          },
        ),
        
        routes: {
          ...AppRoutes.getRoutes(),
          '/badges': (context) => BadgesPage(),
          '/moodCheck': (context) => MoodCheckPage(key: ValueKey(AppColors.currentThemeId)), // ✅ Force rebuild
        },
        
        // ✅ GESTION DES ROUTES DYNAMIQUES (redirections email, etc.)
        onGenerateRoute: (settings) {
          if (settings.name == '/auth/callback' || settings.name == '/email-confirmed') {
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: AppColors.backgroundPrimary,
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 80, color: AppColors.primary),
                        SizedBox(height: 24),
                        Text(
                          'Email confirmé ! ✅',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Tu peux maintenant fermer cette page et te connecter.',
                          style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
           return null;
        },
      ),
    );
  }



  // ✅ FONCTION POUR DÉTERMINER LA DESTINATION DE DÉPART
  Future<AppStartDestination> _determineStartDestination() async {
    try {
      // 1. Vérifier si authentifié
      if (!SupabaseService.isAuthenticated) {
        return AppStartDestination.auth;
      }
      
      // 2. Récupérer le profil
      final profile = await SupabaseService.getProfile();
      
      // 3. Si pas de profil → Auth
      if (profile == null) {
        return AppStartDestination.auth;
      }
      
      // 4. Si onboarding pas complété → Onboarding
      if (profile.onboardingCompleted != true) {
        return AppStartDestination.onboarding;
      }
      
      // 5. NOUVEAU : Vérifier si CGU acceptées (bonne version)
      final consentService = ConsentService();
      final hasCgu = await consentService.hasCguAccepted();
      if (!hasCgu) {
        return AppStartDestination.consent;
      }
      
      // 6. Tout est OK → Home
      return AppStartDestination.home;
      
    } catch (e) {
      print('Erreur _determineStartDestination: $e');
      return AppStartDestination.auth;
    }
  }
  
}

// ✅ ENUM POUR LES DESTINATIONS POSSIBLES
enum AppStartDestination {
  auth,        // Pas authentifié
  onboarding,  // Authentifié mais onboarding incomplet
  consent,     
  home,        // Authentifié et onboarding complété
}
