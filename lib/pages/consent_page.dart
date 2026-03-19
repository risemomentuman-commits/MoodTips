import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/notification_service.dart';
import '../services/consent_service.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({Key? key}) : super(key: key);

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  // ── CGU (obligatoire, NON pré-cochée — exigence RGPD) ──
  bool _cguAccepted = false;

  // ── Consentements existants ──
  bool _notificationsEnabled = true;
  bool _dataCollectionEnabled = true;
  bool _healthDataEnabled = true;
  bool _calendarEnabled = true;

  // ── IRM v2 (optionnel, NON pré-coché — consentement séparé RGPD) ──
  bool _irmConsentEnabled = false;

  bool _isLoading = false;

  final ConsentService _consentService = ConsentService();

  /// Le bouton n'est actif que si les CGU sont acceptées
  bool get _canContinue => _cguAccepted && !_isLoading;

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
                    // ── Header ──
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

                    // ══════════════════════════════════════════
                    // SECTION : CONDITIONS GÉNÉRALES (NOUVEAU)
                    // ══════════════════════════════════════════
                    _buildSectionLabel(
                      'Conditions d\'utilisation',
                      subtitle: 'Obligatoire pour utiliser MoodTips',
                    ),
                    SizedBox(height: 10),
                    _buildCguCard(),
                    SizedBox(height: 24),

                    // ── SECTION : ESSENTIEL ──
                    _buildSectionLabel('Essentiel'),
                    SizedBox(height: 10),
                    _buildConsentCard(
                      icon: Icons.storage_outlined,
                      title: 'Données de l\'app',
                      description: 'Sauvegarde tes check-ins, scores IRM et progression. Requis pour utiliser MoodTips.',
                      value: _dataCollectionEnabled,
                      onChanged: (_) {},
                      isRequired: true,
                    ),
                    SizedBox(height: 24),

                    // ── SECTION : MODE INTELLIGENT & IRM ──
                    _buildSectionLabel(
                      'Mode Intelligent & IRM',
                      subtitle: 'Pour la détection automatique de ton état',
                    ),
                    SizedBox(height: 10),

                    // ── Consentement IRM v2 (NOUVEAU) ──
                    _buildConsentCard(
                      icon: Icons.psychology_outlined,
                      title: 'Recommandations IA (IRM v2)',
                      description: 'Analyse de tes données émotionnelles pour personnaliser '
                          'tes recommandations : baselines, batterie mentale, détection de '
                          'patterns. Ces résultats sont des estimations, pas des diagnostics.',
                      value: _irmConsentEnabled,
                      onChanged: (v) => setState(() => _irmConsentEnabled = v),
                      badge: 'Optionnel',
                      badgeColor: AppColors.primary,
                    ),
                    SizedBox(height: 12),

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
                              'MoodTips est une application de prévention primaire en santé mentale. Elle ne constitue pas un dispositif médical, ne pose pas de diagnostic et ne remplace pas un professionnel de santé.',
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

            // ── Bouton (grisé tant que CGU pas cochée) ──
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Message d'aide si CGU pas cochée
                  if (!_cguAccepted)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Accepte les CGU pour continuer',
                        style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canContinue ? _handleComplete : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Commencer mon voyage 🚀',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // WIDGET : Carte CGU avec checkbox
  // ══════════════════════════════════════════
  Widget _buildCguCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _cguAccepted ? AppColors.primary.withOpacity(0.3) : AppColors.border,
          width: _cguAccepted ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description_outlined, color: AppColors.primary, size: 22),
              ),
              SizedBox(width: 14),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Conditions Générales',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        SizedBox(width: 6),
                        _buildBadge('Requis', AppColors.primary),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'MoodTips est un outil de bien-être, pas un dispositif médical. '
                      'Tes données sont hébergées en Europe et ne sont jamais vendues.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4),
                    ),
                    SizedBox(height: 8),
                    // Lien vers texte complet
                    GestureDetector(
                      onTap: _showCguFullText,
                      child: Text(
                        'Lire le texte complet des CGU →',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Checkbox (NON pré-cochée)
          InkWell(
            onTap: () => setState(() => _cguAccepted = !_cguAccepted),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: _cguAccepted ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _cguAccepted,
                      onChanged: (v) => setState(() => _cguAccepted = v ?? false),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.4),
                        children: [
                          TextSpan(text: 'J\'ai lu et j\'accepte les '),
                          TextSpan(
                            text: 'Conditions Générales d\'Utilisation',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // BOTTOM SHEET : Texte complet des CGU
  // ══════════════════════════════════════════
  void _showCguFullText() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Poignée
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conditions Générales d\'Utilisation',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(),
            // Contenu
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version ${ConsentService.currentCguVersion} — 26 février 2026',
                      style: TextStyle(fontSize: 13, color: AppColors.textLight),
                    ),
                    SizedBox(height: 16),
                    _cguSection('Article 1 — Objet et nature du service',
                      'MoodTips est une application mobile de bien-être émotionnel et de prévention en santé mentale. '
                      'Elle intègre un système algorithmique (IRM v2) qui personnalise les recommandations à partir '
                      'de l\'analyse de vos données émotionnelles.\n\n'
                      'L\'Application NE constitue PAS un dispositif médical, un service de psychothérapie, '
                      'un outil de diagnostic, ni un service d\'urgence. Elle ne remplace en aucun cas un suivi professionnel.\n\n'
                      'Les prédictions et scores générés par l\'algorithme sont des estimations statistiques '
                      'et ne constituent ni un diagnostic ni un avis médical.',
                    ),
                    _cguSection('Article 4 — Protection des données',
                      'Vos données sont hébergées dans l\'Union Européenne et chiffrées. '
                      'Elles ne sont jamais vendues ni cédées à des tiers.\n\n'
                      'Le système IRM v2 effectue un profilage de vos données émotionnelles. '
                      'Vous pouvez vous y opposer à tout moment dans les paramètres.\n\n'
                      'Vous disposez des droits d\'accès, rectification, suppression, portabilité '
                      'et opposition conformément au RGPD.',
                    ),
                    _cguSection('Article 7 — Orientation professionnelle',
                      'En cas de détresse détectée par l\'algorithme, l\'Application affichera un message '
                      'encourageant à consulter un professionnel. Ces alertes sont générées automatiquement '
                      'et leur absence ne garantit pas l\'absence de problème.\n\n'
                      'En cas d\'urgence : 3114 (prévention suicide, gratuit, 24h/24) ou 15 (SAMU).',
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Le texte intégral des CGU est disponible sur\nwww.moodtips.fr/cgu',
                              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Contact : contact@moodtips.fr',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cguSection(String title, String body) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          SizedBox(height: 8),
          Text(body, style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // WIDGETS EXISTANTS (inchangés)
  // ══════════════════════════════════════════

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
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    if (isRequired) _buildBadge('Requis', AppColors.primary),
                    if (badge != null && !isRequired) _buildBadge(badge, badgeColor ?? AppColors.success),
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

  // ══════════════════════════════════════════
  // HANDLER : Complétion (mis à jour)
  // ══════════════════════════════════════════
  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);

    try {
      // 1. Enregistrer acceptation CGU (traçabilité RGPD)
      final cguOk = await _consentService.acceptCgu();
      if (!cguOk) throw Exception('Erreur enregistrement CGU');

      // 2. Enregistrer consentement IRM v2 si activé
      if (_irmConsentEnabled) {
        await _consentService.acceptIrmConsent();
      }

      // 3. Permissions notifications
      if (_notificationsEnabled && !kIsWeb) {
        try {
          await NotificationService.requestPermission();
          await NotificationService.scheduleIRMNotifications();
        } catch (e) {
          print('⚠️ Notifications setup failed: $e');
        }
      }

      // 4. Sauvegarder les autres consentements dans profil
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
        await Supabase.instance.client.from('profiles').insert({
          ...data,
          'id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
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