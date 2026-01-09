import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/notification_service.dart';

class OnboardingConsentPage extends StatefulWidget {
  @override
  _OnboardingConsentPageState createState() => _OnboardingConsentPageState();
}

class _OnboardingConsentPageState extends State<OnboardingConsentPage> {
  bool _consentNotifications = false;
  bool _consentData = true;
  bool _isLoading = false;

  Future<void> _handleNext() async {
    if (!_consentData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le traitement des données est requis pour utiliser l\'app 💜'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Sauvegarder les consents + marquer onboarding terminé
      await SupabaseService.updateProfile({
        'consent_notifications': _consentNotifications,
        'consent_data': _consentData,
        'onboarding_completed': true,  // ✅ AJOUTÉ
        'onboarding_step': 4,
      });

      // 2. Marquer aussi en local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);  // ✅ AJOUTÉ

      if (!mounted) return;

      final granted = await NotificationService.requestPermission();
      if (granted) {
      await NotificationService.scheduleDailyNotifications();
      }
      
      // 3. Aller vers Welcome (qui ira ensuite vers MoodCheck)
      Navigator.pushReplacementNamed(context, AppRoutes.welcome);  // ✅ MODIFIÉ
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildConsentCard({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
    required bool isRequired,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Opacity(
            opacity: animValue,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: value
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: value
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: value ? 20 : 10,
                    offset: Offset(0, value ? 8 : 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (isRequired) ...[
                                  SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Requis',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: value,
                        onChanged: onChanged,
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.only(left: 56),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.secondary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AppBar
              Padding(
                padding: EdgeInsets.all(16),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icône
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.verified_user_outlined, size: 32, color: Colors.white),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 24),

                      // Titre
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 800),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          'Dernière étape 🎉',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.2,
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      // Sous-titre
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 1000),
                        builder: (context, value, child) {
                          return Opacity(opacity: value, child: child);
                        },
                        child: Text(
                          'Tes préférences de confidentialité',
                          style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                        ),
                      ),

                      SizedBox(height: 32),

                      // Cards de consentement
                      _buildConsentCard(
                        title: 'Notifications',
                        description: 'Reçois des rappels bienveillants pour prendre soin de toi au quotidien',
                        icon: Icons.notifications_outlined,
                        value: _consentNotifications,
                        onChanged: (value) => setState(() => _consentNotifications = value),
                        isRequired: false,
                        index: 0,
                      ),

                      SizedBox(height: 16),

                      _buildConsentCard(
                        title: 'Données',
                        description: 'Nécessaire pour sauvegarder tes préférences et suivre ta progression',
                        icon: Icons.security_outlined,
                        value: _consentData,
                        onChanged: (value) => setState(() => _consentData = value),
                        isRequired: true,
                        index: 1,
                      ),

                      SizedBox(height: 24),

                      // Note de sécurité
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 1400),
                        builder: (context, value, child) {
                          return Opacity(opacity: value, child: child);
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tes données sont chiffrées et sécurisées',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bouton
              Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continuer',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}