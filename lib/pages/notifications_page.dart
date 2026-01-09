import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';  // ✅ NOUVEAU
import '../utils/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _notificationsEnabled = false;

  String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
  
  // ✅ NOUVEAU : 3 horaires personnalisables
  TimeOfDay _morningTime = TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _afternoonTime = TimeOfDay(hour: 14, minute: 30);
  TimeOfDay _eveningTime = TimeOfDay(hour: 19, minute: 0);
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final profile = await SupabaseService.getProfile();
      
      if (profile != null) {
        setState(() {
          _notificationsEnabled = profile.consentNotifications ?? false;
        });
      }
    } catch (e) {
      print('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      // Sauvegarder dans Supabase
      await SupabaseService.updateProfile({
        'consent_notifications': _notificationsEnabled,
      });

      // ✅ NOUVEAU : Activer ou désactiver les notifications
      await NotificationService.enableNotifications(_notificationsEnabled);
      
      // Si activées, programmer avec les horaires personnalisés
      if (_notificationsEnabled) {
        await NotificationService.scheduleDailyNotifications(
          morningHour: _morningTime.hour,
          morningMinute: _morningTime.minute,
          afternoonHour: _afternoonTime.hour,
          afternoonMinute: _afternoonTime.minute,
          eveningHour: _eveningTime.hour,
          eveningMinute: _eveningTime.minute,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Paramètres enregistrés ! ✨'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime(String slot) async {
    TimeOfDay initialTime;
    
    switch (slot) {
      case 'morning':
        initialTime = _morningTime;
        break;
      case 'afternoon':
        initialTime = _afternoonTime;
        break;
      case 'evening':
        initialTime = _eveningTime;
        break;
      default:
        return;
    }
    
    final TimeOfDay? picked = await showTimePicker(
  context: context,
  initialTime: initialTime,
  builder: (context, child) {
    return MediaQuery(  // ✅ Force 24h
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
  },
);

    if (picked != null) {
      setState(() {
        switch (slot) {
          case 'morning':
            _morningTime = picked;
            break;
          case 'afternoon':
            _afternoonTime = picked;
            break;
          case 'evening':
            _eveningTime = picked;
            break;
        }
      });
    }
  }

  Widget _buildTimeSlot({
    required String emoji,
    required String label,
    required TimeOfDay time,
    required String slot,
  }) {
    return GestureDetector(
      onTap: () => _selectTime(slot),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
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
              _formatTime(time),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.edit_outlined, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePreview() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Messages variés',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• "Comment te sens-tu en ce moment ? 🌿"\n'
            '• "Prends un instant pour toi 💙"\n'
            '• "Un petit check-in ? 😊"\n'
            '• "Comment va ton humeur ? ✨"',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
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
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.notifications_outlined, size: 32, color: Colors.white),
                            ),

                            SizedBox(height: 24),

                            Text(
                              'Rappels bienveillants',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              '3 check-ins doux par jour pour prendre soin de toi',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textMedium,
                              ),
                            ),

                            SizedBox(height: 32),

                            // Switch principal
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _notificationsEnabled 
                                      ? AppColors.primary.withOpacity(0.3) 
                                      : Colors.grey.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.notifications_active_outlined, 
                                                color: AppColors.primary, size: 24),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Activer les rappels',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Recevoir des check-ins quotidiens',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _notificationsEnabled,
                                    onChanged: (value) => setState(() => _notificationsEnabled = value),
                                    activeColor: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),

                            if (_notificationsEnabled) ...[
                              SizedBox(height: 32),

                              Text(
                                'Horaires des rappels',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),

                              SizedBox(height: 16),

                              _buildTimeSlot(
                                emoji: '🌅',
                                label: 'Matin',
                                time: _morningTime,
                                slot: 'morning',
                              ),

                              _buildTimeSlot(
                                emoji: '🌞',
                                label: 'Après-midi',
                                time: _afternoonTime,
                                slot: 'afternoon',
                              ),

                              _buildTimeSlot(
                                emoji: '🌙',
                                label: 'Soir',
                                time: _eveningTime,
                                slot: 'evening',
                              ),

                              SizedBox(height: 24),

                              _buildMessagePreview(),
                            ],

                            SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isSaving
                                    ? SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check, size: 24),
                                          SizedBox(width: 8),
                                          Text('Enregistrer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }
}