import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/notification_service.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({Key? key}) : super(key: key);

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _notificationsEnabled = true;
  bool _dataCollectionEnabled = true;
  bool _healthDataEnabled = true;
  bool _calendarEnabled = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.shield_outlined, size: 36, color: Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Dernière étape 🎉',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Choisis ce que tu partages avec MoodTips',
                      style: TextStyle(fontSize: 15, color: AppColors.textMedium),
                    ),

                    SizedBox(height: 28),

                    // ── SECTION : ESSENTIEL ──
                    _buildSectionLabel('Essentiel'),
                    SizedBox(height: 10),

                    _buildConsentCard(
                      icon: Icons.storage_outlined,
                      title: 'Données de l\'app',
                      description: 'Sauvegarde tes check-ins, scores IRM et progression. Requis pour utiliser MoodTips.',
                      value: _dataCollectionEnabled,
                      onChanged: (_) {}, // Non modifiable
                      isRequired: true,
                    ),

                    SizedBox(height: 24),

                    // ── SECTION : MODE INTELLIGENT ──
                    _buildSectionLabel('Mode Intelligent & IRM', subtitle: 'Pour la détection automatique de ton état'),
                    SizedBox(height: 10),

                    _buildConsentCard(
                      icon: Icons.bedtime_outlined,
                      title: 'Santé & Activité',
                      description: 'Sommeil et pas quotidiens via Apple Health / Google Fit. Lecture seule — tes données de santé ne quittent jamais ton appareil.',
                      value: _healthDataEnabled,
                      onChanged: (v) => setState(() => _healthDataEnabled = v),
                      badge: 'Recommandé',
                      badgeColor: AppColors.success,
                    ),

                    SizedBox(height: 12),

                    _buildConsentCard(
                      icon: Icons.calendar_today_outlined,
                      title: 'Calendrier',
                      description: 'Nombre et type d\'événements du jour pour évaluer ta charge mentale. Lecture seule — jamais modifié.',
                      value: _calendarEnabled,
                      onChanged: (v) => setState(() => _calendarEnabled = v),
                      badge: 'Recommandé',
                      badgeColor: AppColors.success,
                    ),

                    SizedBox(height: 24),

                    // ── SECTION : NOTIFICATIONS ──
                    _buildSectionLabel('Notifications'),
                    SizedBox(height: 10),

                    _buildConsentCard(
                      icon: Icons.notifications_outlined,
                      title: 'Rappels IRM',
                      description: '2 rappels par jour (8h et 20h) pour consulter ton bilan IRM. Aucun spam.',
                      value: _notificationsEnabled,
                      onChanged: (v) => setState(() => _notificationsEnabled = v),
                    ),

                    SizedBox(height: 20),

                    // ⚠️ Disclaimer médical
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'MoodTips est une app de bien-être. Elle ne remplace pas un professionnel de santé.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Sécurité
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Données chiffrées · Conformité RGPD · Zéro vente de données',
                              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 8),

                    // Lien privacy
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.privacy),
                        child: Text(
                          'Voir la politique de confidentialité complète',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bouton
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Commencer mon voyage 🚀',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: 0.5)),
        if (subtitle != null) ...[
          SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ],
    );
  }

  Widget _buildConsentCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isRequired = false,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? AppColors.primary.withOpacity(0.3) : AppColors.border,
          width: value ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    SizedBox(width: 6),
                    if (isRequired)
                      _buildBadge('Requis', AppColors.primary),
                    if (badge != null && !isRequired)
                      _buildBadge(badge, badgeColor ?? AppColors.success),
                  ],
                ),
                SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4)),
              ],
            ),
          ),
          SizedBox(width: 8),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: isRequired ? null : onChanged,
              activeColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);

    try {
      // 1. Permissions notifications
      if (_notificationsEnabled && !kIsWeb) {
        await NotificationService.requestPermission();
        await NotificationService.scheduleIRMNotifications();
      }

      // 2. Sauvegarder consentements dans profil
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final existingProfile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final data = {
        'notifications_enabled': _notificationsEnabled,
        'data_collection_enabled': _dataCollectionEnabled,
        'health_data_enabled': _healthDataEnabled,
        'calendar_enabled': _calendarEnabled,
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingProfile != null) {
        await Supabase.instance.client.from('profiles').update(data).eq('id', userId);
      } else {
        await Supabase.instance.client.from('profiles').insert({...data, 'id': userId, 'created_at': DateTime.now().toIso8601String()});
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.moodCheck);

      await Future.delayed(Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenue sur MoodTips ! 🎉'), backgroundColor: AppColors.primary, duration: Duration(seconds: 3)),
      );
    } catch (e) {
      print('❌ Erreur consent: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}