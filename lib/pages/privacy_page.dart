import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../widgets/irm_consent_toggle.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
            Text('\u26A0\uFE0F Cette action est irréversible !'),
            SizedBox(height: 16),
            Text('Toutes tes données seront définitivement supprimées :',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('\u2022 Profil et préférences'),
            Text('\u2022 Historique des check-ins'),
            Text('\u2022 Scores IRM et statistiques'),
            Text('\u2022 Données dérivées par l\'IA (baselines, patterns)'),
            Text('\u2022 Objectifs et badges'),
            SizedBox(height: 12),
            Text(
              'Délai de suppression : 30 jours maximum.\n'
              'Les données de facturation sont conservées 10 ans (obligation légale).',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
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
    try {
      // Afficher le chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        Navigator.pop(context);
        return;
      }

      // Récupérer toutes les données utilisateur
      final profile = await client.from('profiles').select().eq('id', userId).maybeSingle();
      final profileDynamic = await client.from('user_profiles_dynamic').select().eq('user_id', userId).maybeSingle();
      final moodLogs = await client.from('mood_logs').select('*, emotions(name)').eq('user_id', userId).order('created_at', ascending: false);
      // mood_contexts lié via mood_logs
      final moodLogIds = (moodLogs as List).map((m) => m['id']).toList();
      List moodContexts = [];
      if (moodLogIds.isNotEmpty) {
        moodContexts = await client.from('mood_contexts').select().inFilter('mood_log_id', moodLogIds);
      }
      final tipsSessions = await client.from('tips_sessions').select('*, tips(title, category)').eq('user_id', userId);
      final irmScores = await client.from('irm_scores_timeline').select().eq('user_id', userId).order('timestamp', ascending: false);
      final dailyHealth = await client.from('daily_health_data').select().eq('user_id', userId).order('date', ascending: false);
      final dataSources = await client.from('user_data_sources').select().eq('user_id', userId);

      // Construire le JSON
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'export_version': '1.0',
        'user_id': userId,
        'profile': profile,
        'profile_dynamic': profileDynamic,
        'mood_logs': moodLogs,
        'mood_contexts': moodContexts,
        'tips_sessions': tipsSessions,
        'irm_scores': irmScores,
        'daily_health_data': dailyHealth,
        'data_sources': dataSources,
        'metadata': {
          'tables_exported': 8,
          'mood_logs_count': (moodLogs as List).length,
          'irm_scores_count': (irmScores as List).length,
          'daily_health_count': (dailyHealth as List).length,
          'tips_sessions_count': (tipsSessions as List).length,
        },
      };

      // Sauvegarder en fichier
      final dir = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/moodtips_export_$date.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );

      // Fermer le chargement
      if (context.mounted) Navigator.pop(context);

      // Partager
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MoodTips - Export de mes données ($date)',
        text: 'Voici l\'export complet de mes données MoodTips (droit de portabilité RGPD Art. 20)',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['emoji'] ?? '\u2022',
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

  /// Section avec du contenu texte libre (pas de liste)
  Widget _buildTextSection({
    required IconData icon,
    required String title,
    required String text,
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
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.5)),
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
                      // ══════════════════════════════════════
                      // HEADER
                      // ══════════════════════════════════════
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
                                Text('Politique de confidentialité · Fév 2026',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // ══════════════════════════════════════
                      // DISCLAIMER MÉDICAL
                      // ══════════════════════════════════════
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
                              'MoodTips est une application de prévention primaire en santé mentale. '
                              'Elle ne constitue pas un dispositif médical, ne pose pas de diagnostic '
                              'et ne remplace en aucun cas l\'avis d\'un professionnel de santé '
                              '(médecin, psychologue, psychiatre). '
                              'En cas de détresse psychologique, contacte le 3114 (gratuit, 24h/24) '
                              'ou consulte un professionnel.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                     

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // DONNÉES COLLECTÉES (mis à jour)
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.data_usage_outlined,
                        title: 'Données collectées',
                        items: [
                          {
                            'emoji': '\uD83D\uDE0A',
                            'title': 'États émotionnels',
                            'desc': 'Tes check-ins quotidiens et humeurs enregistrés dans l\'app.',
                          },
                          {
                            'emoji': '\uD83C\uDFC3',
                            'title': 'Données de santé (avec ta permission)',
                            'desc': 'Pas de comptage, qualité du sommeil via Apple Health ou Google Fit. Lecture seule, jamais modifiées.',
                          },
                          {
                            'emoji': '\uD83D\uDCC5',
                            'title': 'Calendrier (avec ta permission)',
                            'desc': 'Nombre et type d\'événements du jour uniquement, pour le calcul IRM. Lecture seule.',
                          },
                          {
                            'emoji': '\uD83E\uDDE0',
                            'title': 'Score IRM et données dérivées par l\'IA',
                            'desc': 'Ton Indice de Régulation Mentale, tes baselines personnalisées, '
                                'patterns émotionnels détectés, prédictions et insights générés '
                                'par le système IRM v2.',
                          },
                          {
                            'emoji': '\uD83D\uDC64',
                            'title': 'Profil',
                            'desc': 'Email, prénom, date de naissance, objectifs, préférences.',
                          },
                          {
                            'emoji': '\uD83D\uDCF1',
                            'title': 'Données techniques',
                            'desc': 'Type d\'appareil, système d\'exploitation, version de l\'app, données de connexion.',
                          },
                          {
                            'emoji': '\uD83D\uDCB3',
                            'title': 'Paiement',
                            'desc': 'Géré exclusivement par l\'App Store / Google Play. Nous n\'avons jamais accès à tes coordonnées bancaires.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // NOUVEAU : BASES LÉGALES
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.balance_outlined,
                        title: 'Pourquoi on traite tes données',
                        iconColor: AppColors.secondary,
                        items: [
                          {
                            'emoji': '\u2705',
                            'title': 'Ton consentement',
                            'desc': 'Pour le traitement par l\'IA (IRM v2), le profilage et les analyses prédictives. Tu peux le retirer à tout moment.',
                          },
                          {
                            'emoji': '\uD83D\uDCDD',
                            'title': 'Exécution du service',
                            'desc': 'Pour te fournir le service de base : création de compte, suivi d\'humeur, conseils.',
                          },
                          {
                            'emoji': '\uD83D\uDD27',
                            'title': 'Intérêt légitime',
                            'desc': 'Pour améliorer l\'app, le support client et la sécurité.',
                          },
                          {
                            'emoji': '\u2696\uFE0F',
                            'title': 'Obligation légale',
                            'desc': 'Pour conserver les données de facturation (10 ans, obligation comptable).',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // MODE INTELLIGENT & IRM (mis à jour)
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.psychology,
                        title: 'Mode Intelligent & IRM v2',
                        iconColor: AppColors.secondary,
                        items: [
                          {
                            'emoji': '\uD83E\uDD16',
                            'title': 'Comment fonctionne l\'algorithme',
                            'desc': 'L\'IRM v2 analyse ton historique émotionnel pour calculer des baselines personnalisées, '
                                'un score de « batterie mentale », détecter des patterns récurrents et te proposer '
                                'des prédictions et recommandations adaptées.',
                          },
                          {
                            'emoji': '\u26A0\uFE0F',
                            'title': 'Ce ne sont que des estimations',
                            'desc': 'Les résultats de l\'algorithme sont des estimations statistiques, pas des diagnostics. '
                                'L\'absence d\'alerte ne signifie pas l\'absence de problème.',
                          },
                          {
                            'emoji': '\uD83D\uDD12',
                            'title': 'Traitement des données de santé',
                            'desc': 'Les données brutes de santé (sommeil, pas) sont traitées localement sur ton appareil. '
                                'Seul le score IRM final est stocké sur nos serveurs.',
                          },
                          {
                            'emoji': '\u270B',
                            'title': 'Tu contrôles tout',
                            'desc': 'Tu peux désactiver l\'IRM v2 à tout moment. Tes données dérivées seront supprimées sous 30 jours.',
                          },
                          {
                            'emoji': '\uD83D\uDEAB',
                            'title': 'Aucun partage tiers',
                            'desc': 'Tes données émotionnelles et de santé ne sont jamais partagées avec des tiers ni utilisées à des fins publicitaires.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // NOUVEAU : PROFILAGE (Article 22 RGPD)
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.fingerprint,
                        title: 'Profilage et décisions automatisées',
                        iconColor: Colors.deepPurple,
                        items: [
                          {
                            'emoji': '\uD83D\uDCA1',
                            'title': 'Ce que fait le profilage',
                            'desc': 'L\'algorithme IRM v2 évalue ton état émotionnel pour personnaliser tes recommandations '
                                'et peut déclencher des alertes t\'invitant à consulter un professionnel.',
                          },
                          {
                            'emoji': '\uD83D\uDCC9',
                            'title': 'Impact sur toi',
                            'desc': 'Le profilage influence les contenus affichés (conseils, exercices, insights). '
                                'Il ne produit aucun effet juridique et n\'est utilisé pour aucune décision d\'assurance, '
                                'd\'emploi ou de discrimination.',
                          },
                          {
                            'emoji': '\u270D\uFE0F',
                            'title': 'Ton droit d\'opposition',
                            'desc': 'Tu peux désactiver le profilage à tout moment (toggle ci-dessous ou dans Paramètres → Mode Intelligent). '
                                'Tu conserves l\'accès aux fonctionnalités de base.',
                          },
                          {
                            'emoji': '\uD83D\uDE4B',
                            'title': 'Intervention humaine',
                            'desc': 'Tu peux demander une intervention humaine, exprimer ton point de vue et contester '
                                'les résultats du traitement automatisé en nous contactant à contact@moodtips.fr.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // TOGGLE IRM (contrôle direct)
                      // ══════════════════════════════════════
                      IrmConsentToggle(),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // NOUVEAU : DURÉES DE CONSERVATION
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.timer_outlined,
                        title: 'Durées de conservation',
                        iconColor: Colors.teal,
                        items: [
                          {
                            'emoji': '\uD83D\uDC64',
                            'title': 'Données de compte et d\'usage',
                            'desc': 'Pendant la durée d\'utilisation active + 3 ans après la dernière connexion.',
                          },
                          {
                            'emoji': '\uD83E\uDDE0',
                            'title': 'Données dérivées par l\'IA',
                            'desc': 'Tant que l\'IRM v2 est activé. Supprimées sous 30 jours en cas de désactivation ou suppression du compte.',
                          },
                          {
                            'emoji': '\uD83D\uDCB3',
                            'title': 'Données de facturation',
                            'desc': '10 ans (obligation légale comptable).',
                          },
                          {
                            'emoji': '\uD83D\uDCF1',
                            'title': 'Données techniques et logs',
                            'desc': '1 an maximum.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // NOUVEAU : SOUS-TRAITANTS
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.cloud_outlined,
                        title: 'Hébergement et sous-traitants',
                        iconColor: Colors.blueGrey,
                        items: [
                          {
                            'emoji': '\u2601\uFE0F',
                            'title': 'Supabase (hébergement)',
                            'desc': 'Serveurs situés dans l\'Union Européenne (infrastructure AWS). '
                                'Garanties contractuelles conformes à l\'article 28 du RGPD.',
                          },
                          {
                            'emoji': '\uD83C\uDF0D',
                            'title': 'Transferts internationaux',
                            'desc': 'Tes données sont hébergées dans l\'UE. En cas de transfert hors UE/EEE '
                                '(prestataire technique), des clauses contractuelles types de la Commission européenne sont mises en place.',
                          },
                          {
                            'emoji': '\uD83D\uDEAB',
                            'title': 'Zéro vente de données',
                            'desc': 'Tes données ne sont jamais vendues, louées ni cédées à des tiers. '
                                'Aucune donnée émotionnelle n\'est utilisée à des fins publicitaires.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // DROITS UTILISATEUR (complété)
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.verified_outlined,
                        title: 'Tes droits (RGPD)',
                        items: [
                          {
                            'emoji': '\uD83D\uDD0D',
                            'title': 'Accès',
                            'desc': 'Obtenir une copie de toutes tes données, y compris les données dérivées par l\'IA.',
                          },
                          {
                            'emoji': '\u270F\uFE0F',
                            'title': 'Rectification',
                            'desc': 'Corriger tes données inexactes ou incomplètes.',
                          },
                          {
                            'emoji': '\uD83D\uDDD1\uFE0F',
                            'title': 'Suppression',
                            'desc': 'Supprimer définitivement tes données (sous 30 jours).',
                          },
                          {
                            'emoji': '\uD83D\uDCE6',
                            'title': 'Portabilité',
                            'desc': 'Recevoir tes données dans un format lisible par machine.',
                          },
                          {
                            'emoji': '\u270B',
                            'title': 'Opposition et profilage',
                            'desc': 'T\'opposer au traitement et au profilage par l\'IRM v2 à tout moment.',
                          },
                          {
                            'emoji': '\u23F8\uFE0F',
                            'title': 'Limitation',
                            'desc': 'Demander la limitation du traitement dans les cas prévus par le RGPD.',
                          },
                          {
                            'emoji': '\u21A9\uFE0F',
                            'title': 'Retrait du consentement',
                            'desc': 'Retirer ton consentement à tout moment, sans que cela affecte la licéité du traitement antérieur.',
                          },
                          {
                            'emoji': '\uD83C\uDFDB\uFE0F',
                            'title': 'Réclamation CNIL',
                            'desc': 'Tu peux introduire une réclamation auprès de la CNIL : www.cnil.fr.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // ENGAGEMENTS SÉCURITÉ
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.lock_outline,
                        title: 'Sécurité',
                        items: [
                          {
                            'emoji': '\uD83D\uDD12',
                            'title': 'Chiffrement',
                            'desc': 'Toutes les données sont chiffrées en transit (TLS/SSL) et au repos.',
                          },
                          {
                            'emoji': '\uD83D\uDD11',
                            'title': 'Authentification sécurisée',
                            'desc': 'Accès sécurisé avec limitation des accès selon le principe du moindre privilège.',
                          },
                          {
                            'emoji': '\uD83D\uDCBE',
                            'title': 'Sauvegardes',
                            'desc': 'Sauvegardes régulières pour prévenir toute perte de données.',
                          },
                        ],
                      ),

                      SizedBox(height: 16),

                      // ══════════════════════════════════════
                      // CONDITIONS D'UTILISATION (corrigé 18 ans)
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.article_outlined,
                        title: 'Conditions d\'utilisation',
                        items: [
                          {
                            'emoji': '\uD83D\uDCF1',
                            'desc':
                                'MoodTips est fourni à des fins de bien-être personnel uniquement.',
                          },
                          {
                            'emoji': '\uD83D\uDD1E',
                            'desc':
                                'L\'application est réservée aux personnes de 18 ans et plus, ou avec autorisation parentale.',
                          },
                          {
                            'emoji': '\u2696\uFE0F',
                            'desc':
                                'En utilisant l\'app, tu acceptes nos CGU (version 2.0). Elles peuvent évoluer avec notification préalable de 30 jours.',
                          },
                        ],
                      ),

                      SizedBox(height: 24),
                      
                       // ══════════════════════════════════════
                      // NOUVEAU : RESPONSABLE DU TRAITEMENT
                      // ══════════════════════════════════════
                      _buildSection(
                        icon: Icons.person_outline,
                        title: 'Responsable du traitement',
                        items: [
                          {
                            'emoji': '\uD83D\uDC64',
                            'title': 'Anthony NEMES',
                            'desc': 'Micro-entrepreneur\n'
                                'SIREN : 519482327\n'
                                'Email : contact@moodtips.fr\n'
                                'Adresse : 1015 Route de St Ours 73410 ENTRELACS',
                          },
                        ],
                      ),

                      // ══════════════════════════════════════
                      // MES DONNÉES
                      // ══════════════════════════════════════
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
                                      Text('Télécharger toutes tes données (droit de portabilité)',
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
                                      Text('Suppression sous 30 jours · Action irréversible',
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
                            Text('contact@moodtips.fr',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text('Délai de réponse : 1 mois maximum (art. 12 RGPD)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight)),
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