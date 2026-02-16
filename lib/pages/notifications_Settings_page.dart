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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (kIsWeb) return;

    setState(() => _notificationsEnabled = value);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'notifications_enabled': value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        if (value) {
          await NotificationService.requestPermission();
          await NotificationService.scheduleIRMNotifications();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Notifications activées ! 🔔'), backgroundColor: AppColors.primary),
            );
          }
        } else {
          await NotificationService.cancelAllNotifications();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Notifications désactivées'), backgroundColor: AppColors.textMedium),
            );
          }
        }
      }
    } catch (e) {
      print('Erreur _toggleNotifications: $e');
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
        title: Text('Notifications',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle principal
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
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
                          child: Icon(Icons.notifications_outlined, color: AppColors.primary, size: 24),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rappels IRM',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                              Text('Activer les notifications quotidiennes',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Horaires fixes
                  Text('Horaires des rappels',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  SizedBox(height: 4),
                  Text('2 rappels par jour pour consulter ton bilan IRM',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  SizedBox(height: 16),

                  _buildTimeCard(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Bilan matinal',
                    time: '08:00',
                    subtitle: 'Comment démarres-tu la journée ?',
                  ),
                  SizedBox(height: 12),
                  _buildTimeCard(
                    icon: Icons.nightlight_outlined,
                    label: 'Bilan du soir',
                    time: '20:00',
                    subtitle: 'Comment s\'est passée ta journée ?',
                  ),

                  SizedBox(height: 24),

                  // Info
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ces rappels t\'invitent à consulter ton score IRM et à faire un check-in émotionnel. Discrets et bienveillants.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4),
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

  Widget _buildTimeCard({
    required IconData icon,
    required String label,
    required String time,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
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
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
          Text(time,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}