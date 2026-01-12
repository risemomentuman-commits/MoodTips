import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../services/notification_service.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  
  // Horaires des notifications
  TimeOfDay _morningTime = TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _afternoonTime = TimeOfDay(hour: 13, minute: 30);
  TimeOfDay _eveningTime = TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId != null) {
        final response = await Supabase.instance.client
          .from('profiles')
          .select('notifications_enabled')
          .eq('id', userId)
          .single();
        
        if (mounted) {
          setState(() {
            _notificationsEnabled = response['notifications_enabled'] ?? false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Erreur _loadSettings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    // Sur web, afficher un message d'information
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Les notifications ne sont pas disponibles sur le web.\nUtilise l\'app mobile pour recevoir des rappels !'),
          backgroundColor: AppColors.textMedium,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _notificationsEnabled = value);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      if (userId != null) {
        // Sauvegarder dans Supabase
        await Supabase.instance.client
          .from('profiles')
          .update({
            'notifications_enabled': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

        // Gérer les notifications selon l'état
        if (value) {
          try {
            await NotificationService.requestPermission();
            await NotificationService.scheduleDailyNotifications();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notifications activées ! 🔔'),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          } catch (e) {
            print('Erreur activation notifications: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur lors de l\'activation des notifications'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        } else {
          try {
            await NotificationService.cancelAllNotifications();
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notifications désactivées'),
                  backgroundColor: AppColors.textMedium,
                ),
              );
            }
          } catch (e) {
            print('Erreur désactivation notifications: $e');
          }
        }
      }
    } catch (e) {
      print('Erreur _toggleNotifications: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editTime(BuildContext context, String period, TimeOfDay currentTime) async {
    // Sur web, afficher un message
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cette fonctionnalité est disponible sur l\'app mobile'),
          backgroundColor: AppColors.textMedium,
        ),
      );
      return;
    }

    final newTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime != null) {
      setState(() {
        switch (period) {
          case 'morning':
            _morningTime = newTime;
            break;
          case 'afternoon':
            _afternoonTime = newTime;
            break;
          case 'evening':
            _eveningTime = newTime;
            break;
        }
      });

      // Replanifier les notifications avec les nouveaux horaires
      try {
        await NotificationService.scheduleDailyNotifications();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Horaires mis à jour !'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        print('Erreur mise à jour horaires: $e');
      }
    }
  }

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
        title: Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
        ? Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle principal
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          kIsWeb ? 'Notifications (mobile)' : 'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 1.2,
                        child: Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Message d'info web
                if (kIsWeb) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Les notifications sont disponibles uniquement sur l\'application mobile',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 32),
                
                // Section horaires
                Text(
                  'Horaires des rappels',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 16),
                
                // Matin
                _buildTimeCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Matin',
                  time: _morningTime,
                  onTap: () => _editTime(context, 'morning', _morningTime),
                  enabled: _notificationsEnabled && !kIsWeb,
                ),
                SizedBox(height: 12),
                
                // Après-midi
                _buildTimeCard(
                  icon: Icons.wb_twilight_outlined,
                  label: 'Après-midi',
                  time: _afternoonTime,
                  onTap: () => _editTime(context, 'afternoon', _afternoonTime),
                  enabled: _notificationsEnabled && !kIsWeb,
                ),
                SizedBox(height: 12),
                
                // Soir
                _buildTimeCard(
                  icon: Icons.nightlight_outlined,
                  label: 'Soir',
                  time: _eveningTime,
                  onTap: () => _editTime(context, 'evening', _eveningTime),
                  enabled: _notificationsEnabled && !kIsWeb,
                ),
                
                SizedBox(height: 32),
                
                // Section messages
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Messages variés',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildMessageExample('Comment te sens-tu en ce moment ? 🌸'),
                      _buildMessageExample('Prends un instant pour toi 😌'),
                      _buildMessageExample('Un petit check-in ? 😊'),
                      _buildMessageExample('Comment va ton humeur ? ✨'),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildTimeCard({
    required IconData icon,
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
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
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (enabled && !kIsWeb) ...[
                SizedBox(width: 12),
                Icon(
                  Icons.edit_outlined,
                  color: AppColors.textMedium,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageExample(String message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: AppColors.textMedium,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
