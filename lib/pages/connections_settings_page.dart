import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../services/health_service.dart';
import '../services/calendar_service.dart';
import '../utils/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/irm_consent_toggle.dart';

class ConnectionsSettingsPage extends StatefulWidget {
  const ConnectionsSettingsPage({Key? key}) : super(key: key);

  @override
  State<ConnectionsSettingsPage> createState() => _ConnectionsSettingsPageState();
}

class _ConnectionsSettingsPageState extends State<ConnectionsSettingsPage> {
  Map<String, bool> _connections = {
    'apple_health': false,
    'calendar': false,
  };
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
  }
  
  Future<void> _loadConnectionStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await Supabase.instance.client
          .from('user_data_sources')
          .select()
          .eq('user_id', userId);
      
      setState(() {
        for (var source in response) {
          _connections[source['source_type']] = source['is_active'];
        }
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement connexions: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _toggleConnection(String sourceType) async {
    setState(() => _isLoading = true);
    
    bool success = false;
    String message = '';
    
    try {
      // ✅ Vérifier si on active ou désactive
      bool currentState = _connections[sourceType] ?? false;
      
      if (!currentState) {
        // === ACTIVER ===
        switch (sourceType) {
          case 'apple_health':
            if (kIsWeb) {
              message = 'Apple Health non disponible sur web';
            } else {
              success = await HealthService.requestAuthorization();
              message = success 
                  ? '✅ Apple Health connecté' 
                  : '❌ Permission refusée';
            }
            break;
            
          case 'calendar':
            success = await CalendarService.requestPermissions();
            message = success 
                ? '✅ Calendrier connecté' 
                : '❌ Permission refusée';
            break;
        }
        
        if (success) {
          setState(() {
            _connections[sourceType] = true;
          });
        }
      } else {
        // === DÉSACTIVER ===
        // ✅ Désactiver directement dans Supabase
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client.from('user_data_sources').upsert(
            {
              'user_id': userId,
              'source_type': sourceType,
              'is_active': false,
              'last_sync_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id,source_type',
          );
          
          setState(() {
            _connections[sourceType] = false;
          });
          
          success = true;
          message = '🔕 ${sourceType == 'calendar' ? 'Calendrier' : 'Apple Health'} déconnecté';
        }
      }
      
      if (mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur toggle connexion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
              AppColors.backgroundPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios),
                            onPressed: () => Navigator.pop(context),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Connexions',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 8),
                      
                      // Description
                      Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          'Pour activer le Mode Intelligent',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Info Mode Intelligent
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Mode Intelligent',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Connecte tes données pour une détection automatique de ton état émotionnel et des suggestions ultra-personnalisées',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // ── Consentement IRM v2 ──
                      IrmConsentToggle(
                        onConsentChanged: (isEnabled) {
                          // Optionnel : recharger les connexions ou adapter l'UI
                          _loadConnectionStatus();
                        },
                      ),
                      SizedBox(height: 16),

                      
                      // Apple Health (si iOS)
                      if (!kIsWeb && Platform.isIOS) ...[
                        _buildConnectionTile(
                          icon: Icons.favorite,
                          title: 'Apple Health',
                          description: 'Sommeil, activité physique',
                          sourceType: 'apple_health',
                          isConnected: _connections['apple_health'] ?? false,
                          color: Colors.red,
                        ),
                        
                        SizedBox(height: 16),
                      ],
                      
                      // Calendrier
                      _buildConnectionTile(
                        icon: Icons.calendar_today,
                        title: 'Calendrier',
                        description: 'Détection événements stressants',
                        sourceType: 'calendar',
                        isConnected: _connections['calendar'] ?? false,
                        color: Colors.orange,
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Section Confidentialité
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  color: AppColors.success,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Confidentialité',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildPrivacyItem('✓ Tes données restent sur TON téléphone'),
                            _buildPrivacyItem('✓ Aucune vente à des tiers'),
                            _buildPrivacyItem('✓ Déconnexion à tout moment'),
                            _buildPrivacyItem('✓ Suppression complète possible'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
  
  Widget _buildConnectionTile({
    required IconData icon,
    required String title,
    required String description,
    required String sourceType,
    required bool isConnected,
    required Color color,
  }) {
    return Container(
       margin: EdgeInsets.symmetric(horizontal: 0), // ✅ Ajouter
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          
          SizedBox(width: 16),
          
          Expanded(
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
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: isConnected,
            onChanged: _isLoading ? null : (_) => _toggleConnection(sourceType),
            activeColor: color,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrivacyItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textDark,
          height: 1.5,
        ),
      ),
    );
  }
}