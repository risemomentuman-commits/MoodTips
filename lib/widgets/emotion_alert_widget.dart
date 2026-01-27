// lib/widgets/emotion_alert_widget.dart

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/emotion_analysis_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EmotionAlertWidget extends StatelessWidget {
  final int alertLevel;
  final String message;
  final String action;
  final int consecutiveNegative;
  final VoidCallback onDismiss;

  const EmotionAlertWidget({
    Key? key,
    required this.alertLevel,
    required this.message,
    required this.action,
    required this.consecutiveNegative,
    required this.onDismiss,
  }) : super(key: key);

  Color get _alertColor {
    switch (alertLevel) {
      case 3:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 1:
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  IconData get _alertIcon {
    switch (alertLevel) {
      case 3:
        return Icons.favorite;
      case 2:
        return Icons.warning_amber_rounded;
      case 1:
        return Icons.info_outline;
      default:
        return Icons.lightbulb_outline;
    }
  }

  String get _alertTitle {
    switch (alertLevel) {
      case 3:
        return 'Prends soin de toi 💜';
      case 2:
        return 'On est là pour toi';
      case 1:
        return 'Petit moment difficile ?';
      default:
        return 'Hey !';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _alertColor.withOpacity(0.15),
            _alertColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _alertColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _alertColor.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Bouton fermer
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(Icons.close, size: 20, color: AppColors.textMedium),
              onPressed: () async {
                await EmotionAnalysisService.dismissAlert();
                onDismiss();
              },
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
            ),
          ),
          
          // Contenu
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec icône
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _alertColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_alertIcon, color: _alertColor, size: 24),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _alertTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '$consecutiveNegative émotions difficiles récemment',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textDark,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Actions selon le niveau
                _buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    switch (action) {
      case 'strong':
        return _buildStrongActions(context);
      case 'exercise':
        return _buildExerciseActions(context);
      case 'suggestion':
        return _buildSuggestionActions(context);
      default:
        return SizedBox.shrink();
    }
  }

  // Actions pour alerte FORTE (niveau 3)
  Widget _buildStrongActions(BuildContext context) {
    return Column(
      children: [
        // Bouton exercice principal
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final tipId = await EmotionAnalysisService.getRecommendedExercise(alertLevel);
              if (tipId != null) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.tipsDetail,
                  arguments: tipId,
                );
              }
            },
            icon: Icon(Icons.self_improvement),
            label: Text('Faire un exercice maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _alertColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 12),
        
        // Bouton ressources d'aide
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              _showHelpResources(context);
            },
            icon: Icon(Icons.support_agent),
            label: Text('Ressources d\'aide'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _alertColor,
              side: BorderSide(color: _alertColor, width: 2),
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 8),
        
        // Bouton "Plus tard"
        TextButton(
          onPressed: () async {
            await EmotionAnalysisService.dismissAlert();
            onDismiss();
          },
          child: Text('Plus tard'),
        ),
      ],
    );
  }

  // Actions pour alerte MODÉRÉE (niveau 2)
  Widget _buildExerciseActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              final tipId = await EmotionAnalysisService.getRecommendedExercise(alertLevel);
              if (tipId != null) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.tipsDetail,
                  arguments: tipId,
                );
              }
            },
            child: Text('Oui, essayons'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _alertColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        SizedBox(width: 12),
        
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              await EmotionAnalysisService.dismissAlert();
              onDismiss();
            },
            child: Text('Plus tard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _alertColor,
              side: BorderSide(color: _alertColor, width: 2),
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Actions pour alerte LÉGÈRE (niveau 1)
  Widget _buildSuggestionActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              final tipId = await EmotionAnalysisService.getRecommendedExercise(alertLevel);
              if (tipId != null) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.tipsDetail,
                  arguments: tipId,
                );
              }
            },
            child: Text('Bonne idée'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _alertColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        SizedBox(width: 12),
        
        TextButton(
          onPressed: () async {
            await EmotionAnalysisService.dismissAlert();
            onDismiss();
          },
          child: Text('Ça va, merci'),
        ),
      ],
    );
  }

  // Dialog avec ressources d'aide
  void _showHelpResources(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Ressources d\'aide'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Si tu te sens submergé(e), n\'hésite pas à en parler :',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              
              _buildResourceItem(
                icon: Icons.phone,
                title: '3114 - Prévention suicide',
                subtitle: 'Numéro gratuit, 24h/24, 7j/7',
                onTap: () async {
                  final uri = Uri.parse('tel:3114');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
              
              Divider(height: 24),
              
              _buildResourceItem(
                icon: Icons.psychology,
                title: 'Trouver un psychologue',
                subtitle: 'Annuaire des psychologues',
                onTap: () async {
                  final uri = Uri.parse('https://www.psychologue.net');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              
              Divider(height: 24),
              
              _buildResourceItem(
                icon: Icons.favorite,
                title: 'Urgences',
                subtitle: 'En cas d\'urgence : 15 (SAMU)',
                onTap: () async {
                  final uri = Uri.parse('tel:15');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ],
          ),
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

  Widget _buildResourceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
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
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
