// lib/widgets/push_notification_settings_widget.dart
// Widget pour gérer les notifications push dans Settings

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/web_notification_service.dart';
import '../utils/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Ajouter

class PushNotificationSettingsWidget extends StatefulWidget {
  @override
  _PushNotificationSettingsWidgetState createState() => _PushNotificationSettingsWidgetState();
}

class _PushNotificationSettingsWidgetState extends State<PushNotificationSettingsWidget> {
  bool _isEnabled = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    if (!kIsWeb) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Lire depuis Supabase profiles (source de vérité unique)
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId == null) {
        setState(() {
          _isEnabled = false;
          _isLoading = false;
        });
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('notifications_enabled')
          .eq('id', userId)
          .maybeSingle();

      final dbEnabled = profile?['notifications_enabled'] ?? false;

      // Synchroniser avec WebNotificationService
      WebNotificationService.setLocalEnabled(dbEnabled);

      setState(() {
        _isEnabled = dbEnabled;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement notifs: $e');
      setState(() {
        _isEnabled = false;
        _isLoading = false;
      });
    }
  }


  
  Future<void> _toggleNotifications(bool value) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('Non connecté');
      }

      if (value) {
        // === ACTIVER ===
        final ok = await WebNotificationService.requestPermissionAndRegisterToken();

        if (ok) {
          // ✅ Sauvegarder dans Supabase (source de vérité)
          await Supabase.instance.client
              .from('profiles')
              .update({'notifications_enabled': true})
              .eq('id', userId);

          setState(() {
            _isEnabled = true;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔔 Notifications activées'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          setState(() {
            _isEnabled = false;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Autorise les notifications dans ton navigateur'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      } else {
        // === DÉSACTIVER ===
        // ✅ Sauvegarder dans Supabase
        await Supabase.instance.client
            .from('profiles')
            .update({'notifications_enabled': false})
            .eq('id', userId);

        setState(() {
          _isEnabled = false;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🔕 Notifications désactivées')),
          );
        }
      }
    } catch (e) {
      print('❌ Erreur toggle notifs: $e');
      setState(() => _isLoading = false);
    }
  }

  
  @override
  Widget build(BuildContext context) {
    // Ne pas afficher sur mobile natif (utiliser NotificationService à la place)
    if (!kIsWeb) {
      return SizedBox.shrink();
    }
    
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.secondary.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.notifications_active, color: AppColors.primary, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications Push',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Reçois des rappels sur ton téléphone',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isEnabled,
                onChanged: _isLoading ? null : _toggleNotifications,
                activeColor: AppColors.primary,
              ),

            ],
          ),
          
          // Info
          if (_isEnabled) ...[
            SizedBox(height: 20),
            
            Divider(color: AppColors.textLight),
            
            SizedBox(height: 16),
            
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.success.withOpacity(0.1),
                    AppColors.success.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications activées',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tu recevras 3 rappels par jour : matin, après-midi et soir',
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
            ),
            
            SizedBox(height: 16),
            
            // Fonctionnalités
            _buildFeatureItem(
              icon: Icons.phone_iphone,
              text: 'Reçois les notifications même app fermée',
            ),
            
            SizedBox(height: 8),
            
            _buildFeatureItem(
              icon: Icons.local_fire_department,
              text: 'Ne perds plus jamais ton streak',
            ),
            
            SizedBox(height: 8),
            
            _buildFeatureItem(
              icon: Icons.sentiment_satisfied_alt,
              text: 'Rappels doux et bienveillants',
            ),
          ] else ...[
            SizedBox(height: 20),
            
            Divider(color: AppColors.textLight),
            
            SizedBox(height: 16),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active les notifications pour ne pas oublier tes check-ins quotidiens',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}