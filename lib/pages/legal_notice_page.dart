import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class LegalNoticePage extends StatelessWidget {
  const LegalNoticePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mentions légales',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.gavel, color: AppColors.primary, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'MoodTips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Application de prévention primaire en santé mentale',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dernière mise à jour : 26 février 2026',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // 1. Éditeur
            _buildSection(
              'Éditeur de l\'Application',
              children: [
                // ══════════════════════════════════════════
                // ⚠️ À COMPLÉTER avec tes vraies informations
                // ══════════════════════════════════════════
                _buildInfoRow('Nom', 'Anthony NEMES'),
                _buildInfoRow('Statut', 'Micro-entrepreneur (EI)'),
                _buildInfoRow('SIREN', '519482327'),
                _buildInfoRow('SIRET', '519482327'),
                _buildInfoRow('TVA', 'Non applicable (art. 293 B du CGI)'),
                _buildInfoRow('Adresse', '1015 Route de St Ours 73410 ENTRELACS'),
                _buildInfoRow('Email', 'contact@moodtips.fr'),
                _buildInfoRow('Site web', 'www.moodtips.fr'),
              ],
            ),

            // 2. Directeur de la publication
            _buildSection(
              'Directeur de la publication',
              children: [
                _buildInfoRow('Nom', 'Anthony NEMES'),
                _buildInfoRow('Contact', 'contact@moodtips.fr'),
              ],
            ),

            // 3. Hébergement
            _buildSection(
              'Hébergement',
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Application (backend et données)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                _buildInfoRow('Prestataire', 'Supabase, Inc.'),
                _buildInfoRow('Serveurs', 'Union Européenne (AWS)'),
                _buildInfoRow('Site', 'www.supabase.com'),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Site web',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                // ⚠️ À COMPLÉTER avec ton hébergeur web
                _buildInfoRow('Prestataire', '[Infomaniak'),
                _buildInfoRow('Site', 'https://www.infomaniak.com'),
              ],
            ),

            // 4. Propriété intellectuelle
            _buildSection(
              'Propriété intellectuelle',
              text: 'L\'ensemble des contenus de l\'Application (textes, images, '
                  'graphismes, logo, exercices, conseils, algorithmes) sont la '
                  'propriété exclusive de l\'éditeur.\n\n'
                  'La marque « MoodTips » est déposée auprès de l\'INPI. '
                  'Toute reproduction sans autorisation écrite est interdite '
                  'et constitue une contrefaçon sanctionnée par le Code de la '
                  'propriété intellectuelle.',
            ),

            // 5. Nature du service
            _buildSection(
              'Nature du service',
              children: [
                _buildWarningBox(
                  'MoodTips est une application de prévention primaire en santé mentale. '
                  'Il NE constitue PAS un dispositif médical, un service de '
                  'psychothérapie, un outil de diagnostic, ni un service d\'urgence.',
                ),
                SizedBox(height: 12),
                Text(
                  'L\'Application intègre un système algorithmique (IRM v2) qui '
                  'génère des estimations statistiques. Ces résultats ne constituent '
                  'en aucun cas un diagnostic ou un avis médical.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
                ),
                SizedBox(height: 12),
                _buildEmergencyBox(),
              ],
            ),

            // 6. Protection des données
            _buildSection(
              'Protection des données',
              text: 'L\'Application collecte et traite des données personnelles '
                  'conformément au RGPD (Règlement UE 2016/679) et à la loi '
                  'Informatique et Libertés.\n\n'
                  'Les détails complets sont décrits dans la Politique de '
                  'Confidentialité accessible dans Paramètres → Confidentialité.\n\n'
                  'Droits des utilisateurs : accès, rectification, suppression, '
                  'portabilité, opposition au profilage, limitation du traitement, '
                  'retrait du consentement.\n\n'
                  'Contact : contact@moodtips.fr\n'
                  'Réclamation : www.cnil.fr',
            ),

            // 7. Limitation de responsabilité
            _buildSection(
              'Limitation de responsabilité',
              text: 'L\'éditeur ne saurait être tenu responsable des dommages '
                  'directs ou indirects résultant de l\'utilisation des Services, '
                  'et en particulier des prédictions, scores et recommandations '
                  'générés par le système algorithmique IRM v2.',
            ),

            // 8. Droit applicable
            _buildSection(
              'Droit applicable',
              text: 'Les présentes mentions légales sont régies par le droit '
                  'français. En cas de litige, et après tentative de résolution '
                  'amiable, compétence est attribuée aux tribunaux français.',
            ),

            // 9. Contact
            _buildSection(
              'Contact',
              children: [
                _buildInfoRow('Email', 'contact@moodtips.fr'),
                _buildInfoRow('Site', 'www.moodtips.fr'),
                _buildInfoRow('Adresse', '1015 Route de St Ours 73410 ENTRELACS'),
              ],
            ),

            SizedBox(height: 24),

            // Footer
            Center(
              child: Text(
                'MoodTips — Votre allié bien-être quotidien',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // WIDGETS HELPERS
  // ══════════════════════════════════════════

  Widget _buildSection(String title, {String? text, List<Widget>? children}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          if (text != null)
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),
          if (children != null) ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBox() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.phone, color: Colors.red, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En cas de détresse',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '3114 — Prévention suicide (gratuit, 24h/24)\n15 — SAMU',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}