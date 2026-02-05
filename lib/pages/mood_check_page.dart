import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/emotion_analysis_service.dart';
import '../models/emotion.dart';
import '../models/user_profile.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../widgets/emotion_wheel.dart';
import '../widgets/emotion_alert_widget.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/badge_checker.dart';

class MoodCheckPage extends StatefulWidget {
  @override
  _MoodCheckPageState createState() => _MoodCheckPageState();
}

class _MoodCheckPageState extends State<MoodCheckPage> {
  Future<List<Emotion>>? _emotionsFuture;
  Future<UserProfile?>? _profileFuture;
  Future<Map<String, dynamic>>? _emotionAnalysisFuture;
  
  bool _isExpressMode = false;
  bool _showAlert = true;
  
  @override
  void initState() {
    super.initState();
    _emotionsFuture = SupabaseService.getEmotions();
    _profileFuture = SupabaseService.getProfile();
    _loadEmotionAnalysis();
  }

  Future<void> _loadEmotionAnalysis() async {
    final shouldShow = await EmotionAnalysisService.shouldShowAlert();
    if (shouldShow) {
      setState(() {
        _emotionAnalysisFuture = EmotionAnalysisService.analyzeRecentEmotions();
      });
    }
  }

  Future<void> _showExpressSuccess(String emotionName) async {
    HapticFeedback.heavyImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Check-in validé ! Humeur "$emotionName" enregistrée 🎉',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    await BadgeChecker.checkAndShowBadges(context);
    
    setState(() {
      _profileFuture = SupabaseService.getProfile();
      _loadEmotionAnalysis();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comment te sens-tu ?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.bar_chart, color: AppColors.primary, size: 24),
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboard),
                              tooltip: 'Mes statistiques',
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.settings, color: AppColors.primary, size: 24),
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                              tooltip: 'Paramètres',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 🎨 Widget Streak - COULEURS HARMONISÉES
                FutureBuilder<UserProfile?>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return SizedBox.shrink();
                    }

                    final profile = snapshot.data!;

                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.streakGradient, // ✅ HARMONISÉ
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickStat(
                            icon: Icons.local_fire_department,
                            value: '${profile.currentStreak}',
                            label: 'jours de suite',
                            color: Colors.white,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildQuickStat(
                            icon: Icons.check_circle_outline,
                            value: '${profile.totalTipsCompleted}',
                            label: 'tips complétés',
                            color: Colors.white,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Alerte émotionnelle
                if (_showAlert)
                  FutureBuilder<Map<String, dynamic>>(
                    future: _emotionAnalysisFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return SizedBox.shrink();
                      
                      final analysis = snapshot.data!;
                      
                      if (!analysis['shouldShow']) return SizedBox.shrink();
                      
                      return EmotionAlertWidget(
                        alertLevel: analysis['alertLevel'],
                        message: analysis['message'],
                        action: analysis['action'],
                        consecutiveNegative: analysis['consecutiveNegative'],
                        onDismiss: () {
                          setState(() => _showAlert = false);
                        },
                      );
                    },
                  ),

                SizedBox(height: 12),

                // Toggle Mode Express
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isExpressMode ? Icons.flash_on : Icons.tune,
                            color: _isExpressMode ? AppColors.warning : AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isExpressMode ? 'Mode Express' : 'Mode Standard',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                _isExpressMode ? 'Check-in rapide (5 sec)' : 'Parcours complet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isExpressMode,
                        onChanged: (value) {
                          setState(() => _isExpressMode = value);
                          HapticFeedback.lightImpact();
                        },
                        activeColor: AppColors.warning,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  _isExpressMode 
                      ? 'Sélectionne ton émotion et c\'est tout !'
                      : 'Fais tourner la roue et sélectionne',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                ),

                SizedBox(height: 8),

                // 🎯 Roue des émotions - RÉDUITE
                FutureBuilder<List<Emotion>>(
                  future: _emotionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'Erreur de chargement des émotions',
                          style: TextStyle(color: AppColors.error),
                        ),
                      );
                    }

                    return EmotionWheel(
                      emotions: snapshot.data!,
                      onEmotionSelected: (emotion) async {
                        HapticFeedback.mediumImpact();
                        
                        if (_isExpressMode) {
                          final moodLog = await SupabaseService.createMoodLog(emotionId: emotion.id);
                          
                          if (moodLog == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors de l\'enregistrement'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          
                          _showExpressSuccess(emotion.name);
                          
                        } else {
                          final moodLog = await SupabaseService.createMoodLog(emotionId: emotion.id);
                          
                          if (moodLog == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors de l\'enregistrement'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          await BadgeChecker.checkAndShowBadges(context);
                          
                          Navigator.pushNamed(
                            context,
                            AppRoutes.context,
                            arguments: {
                              'emotionId': emotion.id,
                              'moodLogId': moodLog.id,
                            },
                          );
                        }
                      },
                    );
                  },
                ),
                
                SizedBox(height: 12),
                
                // 🆕 Bouton Aide au sommeil - NORMAL AU-DESSUS
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.sleep),
                    icon: Icon(Icons.nightlight, size: 20),
                    label: Text('Aide au sommeil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 8),
                
                // Bouton Feedback
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = 'https://docs.google.com/forms/d/e/1FAIpQLSd5GIhsTxsvTGQULpspFzYboTV3jKXCG8ymRTSU4EYQdOlpUQ/viewform';
                      try {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Impossible d\'ouvrir le lien')),
                        );
                      }
                    },
                    icon: Icon(Icons.feedback, size: 20),
                    label: Text('Feedback Test MoodTips'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
