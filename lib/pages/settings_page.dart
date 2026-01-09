import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class SettingsPage extends StatelessWidget {
  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnexion'),
        content: Text('Es-tu sûr(e) de vouloir te déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.signOut();
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.auth,
          (route) => false,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.favorite, color: AppColors.primary),
            SizedBox(width: 8),
            Text('MoodTips'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Ton compagnon bien-être quotidien'),
            SizedBox(height: 16),
            Text(
              '© 2024 MoodTips',
              style: TextStyle(fontSize: 12, color: AppColors.textMedium),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Paramètres',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Section Tips
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Contenu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 8),

                _buildSettingCard(
                  context: context,
                  icon: Icons.lightbulb_outline,
                  iconColor: Colors.amber,
                  title: 'Tous les tips',
                  subtitle: 'Parcourir tous les conseils',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.tipsList);
                  },
                ),

                SizedBox(height: 24),

                // Section Personnalisation
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Personnalisation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 8),

                _buildSettingCard(
                  context: context,
                  icon: Icons.flag_outlined,
                  iconColor: AppColors.primary,
                  title: 'Mes objectifs',
                  subtitle: 'Modifier mes objectifs',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.onboardingObjectifs,
                      arguments: {'fromSettings': true},
                    );
                  },
                ),

                _buildSettingCard(
                  context: context,
                  icon: Icons.favorite_border,
                  iconColor: AppColors.secondary,
                  title: 'Mes préférences',
                  subtitle: 'Catégories préférées',
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.onboardingPreferences,
                      arguments: {'fromSettings': true},
                    );
                  },
                ),

                SizedBox(height: 24),

                // Section Compte
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Compte',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 8),

                _buildSettingCard(
                  context: context,
                  icon: Icons.person_outline,
                  iconColor: Colors.blue,
                  title: 'Mon profil',
                  subtitle: 'Informations personnelles',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),

                _buildSettingCard(
                  context: context,
                  icon: Icons.notifications_outlined,
                  iconColor: Colors.orange,
                  title: 'Notifications',
                  subtitle: 'Rappels et alertes',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.notifications);
                  },
                ),

                _buildSettingCard(
                  context: context,
                  icon: Icons.lock_outline,
                  iconColor: Colors.green,
                  title: 'Confidentialité',
                  subtitle: 'Données et sécurité',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.privacy);
                  },
                ),

                SizedBox(height: 24),

                // Section Autre
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Autre',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 8),

                _buildSettingCard(
                  context: context,
                  icon: Icons.info_outline,
                  iconColor: AppColors.primary,
                  title: 'À propos',
                  subtitle: 'Version et informations',
                  onTap: () => _showAboutDialog(context),
                ),

                _buildSettingCard(
                  context: context,
                  icon: Icons.logout,
                  iconColor: AppColors.error,
                  title: 'Déconnexion',
                  subtitle: 'Se déconnecter du compte',
                  onTap: () => _handleLogout(context),
                ),

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
