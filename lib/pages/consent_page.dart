import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({Key? key}) : super(key: key);

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _notificationsEnabled = true;
  bool _dataCollectionEnabled = true;
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
                    // Icône
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // Titre
                    Text(
                      'Dernière étape 🎉',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tes préférences de confidentialité',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMedium,
                      ),
                    ),
                    SizedBox(height: 40),
                    
                    // Option Notifications
                    _buildConsentCard(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      description: 'Reçois des rappels bienveillants pour prendre soin de toi au quotidien',
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                      isRequired: false,
                    ),
                    SizedBox(height: 16),
                    
                    // Option Données
                    _buildConsentCard(
                      icon: Icons.shield_outlined,
                      title: 'Données',
                      description: 'Nécessaire pour sauvegarder tes préférences et suivre ta progression',
                      value: _dataCollectionEnabled,
                      onChanged: (value) {
                        setState(() => _dataCollectionEnabled = value);
                      },
                      isRequired: true,
                      requiredLabel: 'Requis',
                    ),
                    SizedBox(height: 24),
                    
                    // Message de sécurité
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tes données sont chiffrées et sécurisées',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bouton de validation
            Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Commencer mon voyage 🚀',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isRequired = false,
    String? requiredLabel,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (isRequired && requiredLabel != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          requiredLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: 64),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleComplete() async {
    // Vérifier que les données sont activées (requis)
    if (!_dataCollectionEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La collecte de données est nécessaire pour utiliser l\'app'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Demander la permission des notifications (seulement si activé et pas sur web)
      if (_notificationsEnabled && !kIsWeb) {
        try {
          await NotificationService.requestPermission();
        } catch (e) {
          print('Erreur notification permission: $e');
          // On continue même si ça échoue
        }
      }

      // 2. Récupérer l'ID utilisateur
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      print('Mise à jour profil pour userId: $userId');
      
      // 3. Vérifier si le profil existe
      final existingProfile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
      
      print('Profil existant: $existingProfile');

      // 4. Mettre à jour ou créer le profil
      if (existingProfile != null) {
        // UPDATE
        await Supabase.instance.client
          .from('profiles')
          .update({
            'notifications_enabled': _notificationsEnabled,
            'data_collection_enabled': _dataCollectionEnabled,
            'onboarding_completed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
        
        print('Profil mis à jour');
      } else {
        // INSERT
        await Supabase.instance.client
          .from('profiles')
          .insert({
            'id': userId,
            'notifications_enabled': _notificationsEnabled,
            'data_collection_enabled': _dataCollectionEnabled,
            'onboarding_completed': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        
        print('Profil créé');
      }
        
      // 5. Planifier les notifications si activées et pas sur web
      if (_notificationsEnabled && !kIsWeb) {
        try {
          await NotificationService.scheduleDailyNotifications();
        } catch (e) {
          print('Erreur planification notifications: $e');
          // On continue même si ça échoue
        }
      }

      if (!mounted) return;

      // 6. Navigation vers la page principale
      Navigator.pushReplacementNamed(context, AppRoutes.moodCheck);

      // 7. Message de bienvenue
      await Future.delayed(Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bienvenue sur MoodTips ! 🎉'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      print('Erreur _handleComplete: $e');
      print('Stack trace: ${StackTrace.current}');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
