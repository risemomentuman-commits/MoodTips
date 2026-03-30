import 'package:flutter/material.dart';
import '../pages/auth_page.dart';
import '../pages/create_account_page.dart';
import '../pages/onboarding_slides_page.dart';
import '../pages/onboarding_objectifs_page.dart';
import '../pages/onboarding_preferences_page.dart';
import '../pages/consent_page.dart';            
import '../pages/mood_check_page.dart';
import '../pages/tips_list_page.dart';
import '../pages/tips_result_page.dart';
import '../pages/tips_detail_page.dart';
import '../pages/tips_player_page.dart';
import '../pages/settings_page.dart';
import '../pages/profile_page.dart';
import '../pages/privacy_page.dart';
import '../pages/context_page.dart';
import '../pages/sleep_page.dart';
import '../pages/intelligent_mode_flow_page.dart';
import '../pages/notifications_Settings_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;  // ← DOIT être présent
import '../pages/legal_notice_page.dart';
import '../pages/irm_detail_page.dart';
import '../pages/irm_history_page.dart';
import '../pages/account_type_page.dart';
import '../pages/enterprise_code_page.dart';

class AppRoutes {
  static const String auth = '/auth';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String createAccount = '/create-account';
  static const String onboardingSlides = '/onboarding-slides';
  static const String onboardingObjectifs = '/onboarding-objectifs';
  static const String onboardingPreferences = '/onboarding-preferences';
  static const String onboardingConsent = '/onboarding-consent';
  static const String moodCheck = '/mood-check';
  static const String tipsList = '/tips-list';
  static const String tipsResult = '/tips-result';
  static const String tipsDetail = '/tips-detail';
  static const String tipsPlayer = '/tips-player';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String privacy = '/privacy';
  static const String context = '/context';
  static const String sleep = '/sleep';
  static const String intelligentMode = '/intelligent-mode';
  static const String legalNotice = '/legal-notice';
  static const String accountType    = '/account-type';
  static const String enterpriseCode = '/enterprise-code';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      auth: (context) => AuthPage(),
      onboarding: (context) => OnboardingSlidesPage(),  // ✅ CORRIGÉ
      home: (context) => MoodCheckPage(),              // ✅ CORRIGÉ
      createAccount: (context) => CreateAccountPage(),
      onboardingSlides: (context) => OnboardingSlidesPage(),
      onboardingObjectifs: (context) => OnboardingObjectifsPage(),
      onboardingPreferences: (context) => OnboardingPreferencesPage(),
      onboardingConsent: (context) => ConsentPage(),
      notifications: (context) => NotificationsSettingsPage(),
      moodCheck: (context) => MoodCheckPage(),
      accountType:    (context) => const AccountTypePage(),
      enterpriseCode: (context) => const EnterpriseCodePage(),
      tipsList: (context) => TipsListPage(),
      sleep: (context) => SleepPage(),
      legalNotice: (context) => LegalNoticePage(),
      intelligentMode: (context) => IntelligentModeFlowPage(),
      '/irm-history': (context) => const IrmHistoryPage(),
      context: (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return ContextPage(
          emotionId: args['emotionId'] as int,
          moodLogId: args['moodLogId'] as int,
        );
      },
      tipsResult: (context) => TipsResultPage(
            emotionId: ModalRoute.of(context)!.settings.arguments as int,
          ),
      tipsDetail: (context) {
        final args = ModalRoute.of(context)!.settings.arguments;
        
        if (args is int) {
          return TipsDetailPage(tipId: args);
        }
        else if (args is Map<String, dynamic>) {
          final id = args['id'];
          if (id == null) {
            return Scaffold(
              appBar: AppBar(title: Text('Erreur')),
              body: Center(child: Text('ID du tip manquant')),
            );
          }
          return TipsDetailPage(tipId: id as int);
        }
        return Scaffold(
          appBar: AppBar(title: Text('Erreur')),
          body: Center(child: Text('Argument invalide: $args')),
        );
      },
      tipsPlayer: (context) {
        final args = ModalRoute.of(context)!.settings.arguments;
        
        if (args is! Map<String, dynamic>) {
          return Scaffold(
            appBar: AppBar(title: Text('Erreur')),
            body: Center(child: Text('Arguments invalides pour le player')),
          );
        }
        
        final tip = args['tip'];
        final sessionId = args['sessionId'];
        
        if (tip == null || sessionId == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Erreur')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Données manquantes'),
                  SizedBox(height: 8),
                  Text('tip: ${tip != null ? "✓" : "✗"}'),
                  Text('sessionId: ${sessionId != null ? "✓" : "✗"}'),
                ],
              ),
            ),
          );
        }
        
        return TipsPlayerPage(
          tip: tip,
          sessionId: sessionId as int,
        );
      },
      settings: (context) => SettingsPage(),
      profile: (context) => ProfilePage(),
      notifications: (context) => NotificationsSettingsPage(),
      privacy: (context) => PrivacyPage(),
    };
  }
}
