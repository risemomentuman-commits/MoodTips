import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import 'connections_settings_page.dart';
import '../services/google_tts_service.dart';
import 'notifications_Settings_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  bool _ttsLoading = false;

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
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.auth, (route) => false);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion'), backgroundColor: AppColors.error),
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
            Text('Version 1.0.0 Beta', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Ton compagnon bien-être quotidien'),
            SizedBox(height: 16),
            Text('© 2026 Rise Momentum', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(String label, TTSGender gender) {
    final isSelected = GoogleTTSService.currentGender == gender;
    return GestureDetector(
      onTap: _ttsLoading ? null : () async {
        setState(() => _ttsLoading = true);
        await GoogleTTSService.setGender(gender);
        await GoogleTTSService.speak('Bonjour, je suis ta voix guidée.');
        setState(() => _ttsLoading = false);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!),
        ),
        child: _ttsLoading && isSelected
            ? SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMedium,
                ),
              ),
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
                      Text('Paramètres',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),

                // ── CONTENU ──
                _buildSectionTitle('Contenu'),
                _buildSettingCard(
                  context: context,
                  icon: Icons.lightbulb_outline,
                  iconColor: Colors.amber,
                  title: 'Tous les tips',
                  subtitle: 'Parcourir tous les conseils',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.tipsList),
                ),

                SizedBox(height: 24),

                // ── VOIX GUIDÉE ──
                _buildSectionTitle('Voix guidée'),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choisis ta voix', style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildVoiceButton('👩 Féminine', TTSGender.female)),
                          SizedBox(width: 12),
                          Expanded(child: _buildVoiceButton('👨 Masculine', TTSGender.male)),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // ── PERSONNALISATION ──
                _buildSectionTitle('Personnalisation'),
                _buildSettingCard(
                  context: context,
                  icon: Icons.flag_outlined,
                  iconColor: AppColors.primary,
                  title: 'Mes objectifs',
                  subtitle: 'Modifier mes objectifs',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.onboardingObjectifs, arguments: {'fromSettings': true}),
                ),
                _buildSettingCard(
                  context: context,
                  icon: Icons.favorite_border,
                  iconColor: AppColors.secondary,
                  title: 'Mes préférences',
                  subtitle: 'Catégories préférées',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.onboardingPreferences, arguments: {'fromSettings': true}),
                ),

                SizedBox(height: 24),

                // ── COMPTE ──
                _buildSectionTitle('Compte'),
                _buildSettingCard(
                  context: context,
                  icon: Icons.person_outline,
                  iconColor: Colors.blue,
                  title: 'Mon profil',
                  subtitle: 'Informations personnelles',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                ),
                _buildSettingCard(
                  context: context,
                  icon: Icons.psychology,
                  iconColor: AppColors.primary,
                  title: 'Mode Intelligent',
                  subtitle: 'Gérer les connexions',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConnectionsSettingsPage())),
                ),

                _buildSettingCard(
                  context: context,
                  icon: Icons.notifications_outlined,
                  iconColor: Colors.orange,
                  title: 'Notifications',
                  subtitle: 'Gérer les rappels IRM',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsSettingsPage()),
                  ),
                ),
                _buildSettingCard(
                  context: context,
                  icon: Icons.lock_outline,
                  iconColor: Colors.green,
                  title: 'Confidentialité',
                  subtitle: 'Données et sécurité',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
                ),

                SizedBox(height: 24),

                // ── AUTRE ──
                _buildSectionTitle('Autre'),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium, letterSpacing: 0.5)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
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
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}