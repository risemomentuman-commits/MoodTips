import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Supabase
  await Supabase.initialize(
    url: 'https://bfyehaltboxxsivqtfhq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmeWVoYWx0Ym94eHNpdnF0ZmhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4NjMzMzEsImV4cCI6MjA4MjQzOTMzMX0.bxiMKHrjRFcIfqcoE7oj6lTlFVjcs-FnP6Mq69eWmdc',
  );

  // Initialiser timezone (seulement si pas web)
  if (!kIsWeb) {
    tz.initializeTimeZones();
  }

  // Initialiser les notifications
  await NotificationService.initialize();
  AudioPreloader.preloadAudio();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            case AppStartDestination.home:
              return MoodCheckPage();
          }
        },
      ),
      
      routes: AppRoutes.getRoutes(),
      
      // ✅ GESTION DES ROUTES DYNAMIQUES (redirections email, etc.)
      onGenerateRoute: (settings) {
        if (settings.name == '/welcome' || settings.name == '/auth/callback' || settings.name == '/email-confirmed') {
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
      
      // 5. Tout est OK → Home
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
  home,        // Authentifié et onboarding complété
}
