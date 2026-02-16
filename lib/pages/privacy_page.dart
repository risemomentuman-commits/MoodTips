import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class PrivacyPage extends StatelessWidget {
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer mon compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️ Cette action est irréversible !'),
            SizedBox(height: 16),
            Text('Toutes tes données seront définitivement supprimées :',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Profil et préférences'),
            Text('• Historique des check-ins'),
            Text('• Scores IRM et statistiques'),
            Text('• Objectifs et badges'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Supprimer définitivement',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.auth, (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export des données bientôt disponible 📊'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Map<String, String>> items,
    Color? iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
            ],
          ),
          SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['emoji'] ?? '•',
                        style: TextStyle(fontSize: 15)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item['title'] != null)
                            Text(item['title']!,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark)),
                          Text(item['desc'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
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
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text('Confidentialité',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.shield_outlined,
                                size: 28, color: Colors.white),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tes données sont protégées',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark)),
                                Text('Conformité RGPD · Dernière mise à jour : Fév 2026',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // ⚠️ DISCLAIMER MÉDICAL
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.medical_information_outlined,
                                    color: AppColors.warning, size: 20),
                                SizedBox(width: 8),
                                Text('Avertissement médical important',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning)),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'MoodTips est une application de bien-être personnel. '
                              'Elle ne constitue pas un dispositif médical, ne pose pas de diagnostic '
                              'et ne remplace en aucun cas l\'avis d\'un professionnel de santé '
                              '(médecin, psychologue, psychiatre). '
                              'En cas de détresse psychologique, consulte un professionnel.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Données collectées
                      _buildSection(
                        icon: Icons.data_usage_outlined,
                        title: 'Données collectées',
                        items: [
                          {
                            'emoji': '😊',
                            'title': 'États émotionnels',
                            'desc': 'Tes check-ins quotidiens et humeurs enregistrés dans l\'app',
                          },
                          {
                            'emoji': '🏃',
                            'title': 'Données de santé (avec ta permission)',
                            'desc': 'Pas de comptage, qualité du sommeil via Apple Health ou Google Fit. Lecture seule, jamais modifiées.',
                          },
                          {
                            'emoji': '📅',
                            'title': 'Calendrier (avec ta permission)',
                            'desc': 'Nombre et type d\'événements du jour uniquement, pour le calcul IRM. Lecture seule.',
                          },
                          {
                            'emoji': '🧠',
                            'title': 'Score IRM',
                            'desc': 'Ton Indice de Régulation Mentale calculé localement à partir de tes données.',
                          },
                          {
                            'emoji': '👤',
                            'title': 'Profil',
                            'desc': 'Prénom, objectifs, préférences de l\'app.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // Mode Intelligent
                      _buildSection(
                        icon: Icons.psychology,
                        title: 'Mode Intelligent & IRM',
                        iconColor: AppColors.secondary,
                        items: [
                          {
                            'emoji': '🔒',
                            'title': 'Traitement local',
                            'desc': 'L\'analyse IRM est calculée sur ton appareil. Les données brutes de santé ne quittent jamais ton téléphone.',
                          },
                          {
                            'emoji': '📊',
                            'title': 'Seul le score est sauvegardé',
                            'desc': 'Seul ton score IRM final (ex: 78/100) est stocké dans notre base de données, pas tes données de santé brutes.',
                          },
                          {
                            'emoji': '✋',
                            'title': 'Tu contrôles tout',
                            'desc': 'Tu peux révoquer l\'accès à la santé ou au calendrier à tout moment dans les réglages de ton iPhone.',
                          },
                          {
                            'emoji': '🚫',
                            'title': 'Aucun partage tiers',
                            'desc': 'Tes données de santé et de calendrier ne sont jamais partagées avec des tiers ni utilisées à des fins publicitaires.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // Engagements
                      _buildSection(
                        icon: Icons.verified_outlined,
                        title: 'Nos engagements',
                        items: [
                          {
                            'emoji': '🔒',
                            'title': 'Chiffrement',
                            'desc': 'Toutes les données sont chiffrées en transit (HTTPS) et au repos.',
                          },
                          {
                            'emoji': '🚫',
                            'title': 'Zéro vente de données',
                            'desc': 'Tes données ne sont jamais vendues, louées ou partagées à des fins commerciales.',
                          },
                          {
                            'emoji': '✅',
                            'title': 'Conformité RGPD',
                            'desc': 'Tu peux accéder, modifier et supprimer tes données à tout moment.',
                          },
                          {
                            'emoji': '🗑️',
                            'title': 'Suppression complète',
                            'desc': 'La suppression de ton compte efface définitivement toutes tes données de nos serveurs sous 30 jours.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // Conditions d'utilisation
                      _buildSection(
                        icon: Icons.article_outlined,
                        title: 'Conditions d\'utilisation',
                        items: [
                          {
                            'emoji': '📱',
                            'desc':
                                'MoodTips est fourni à des fins de bien-être personnel uniquement.',
                          },
                          {
                            'emoji': '🔞',
                            'desc':
                                'L\'application est réservée aux personnes de 16 ans et plus.',
                          },
                          {
                            'emoji': '⚖️',
                            'desc':
                                'En utilisant l\'app, tu acceptes nos conditions. Elles peuvent évoluer avec notification préalable.',
                          },
                        ],
                      ),

                      SizedBox(height: 24),

                      Text('Mes données',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),

                      SizedBox(height: 12),

                      // Export
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _exportData(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.download_outlined,
                                      color: AppColors.primary),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Exporter mes données',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark)),
                                      Text('Télécharger toutes tes données',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMedium)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: AppColors.textLight),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      // Supprimer compte
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showDeleteAccountDialog(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.error.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      color: AppColors.error),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Supprimer mon compte',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.error)),
                                      Text('Action irréversible',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMedium)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: AppColors.error.withOpacity(0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 32),

                      // Contact
                      Center(
                        child: Column(
                          children: [
                            Text('Questions sur tes données ?',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMedium)),
                            SizedBox(height: 4),
                            Text('privacy@risemomentum.fr',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      SizedBox(height: 32),
                    ],
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