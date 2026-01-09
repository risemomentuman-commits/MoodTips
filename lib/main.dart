import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/app_routes.dart';
import 'utils/app_colors.dart';
import 'pages/auth_page.dart';
import 'pages/mood_check_page.dart';
import 'pages/onboarding_slides_page.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Supabase
  await Supabase.initialize(
    url: 'https://bfyehaltboxxsivqtfhq.supabase.co',
    anonKey: 'sb_publishable_i756_vti1aFvEkGRwI-hhQ_ozG5Fuck',
  );

  // Initialiser les notifications
  await NotificationService.initialize();

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
