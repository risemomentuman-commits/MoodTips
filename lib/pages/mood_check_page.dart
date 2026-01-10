import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/emotion.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../widgets/emotion_wheel.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MoodCheckPage extends StatefulWidget {
  @override
  _MoodCheckPageState createState() => _MoodCheckPageState();
}

class _MoodCheckPageState extends State<MoodCheckPage> {
  Future<List<Emotion>>? _emotionsFuture;
  
  @override
  void initState() {
    super.initState();
    _emotionsFuture = SupabaseService.getEmotions();
  }

  Color _getEmotionColor(String emotionName) {
    return AppColors.emotions[emotionName.toLowerCase()] ?? AppColors.primary;
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
                // Header avec Stats et Settings
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
                          // Bouton Stats
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
                              icon: Icon(
                                Icons.bar_chart,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.dashboard);
                              },
                              tooltip: 'Mes statistiques',
                            ),
                          ),
                          SizedBox(width: 12),
                          // Bouton Settings
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
                              icon: Icon(
                                Icons.settings,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.settings);
                              },
                              tooltip: 'Paramètres',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10),

                Text(
                  'Fais tourner la roue et sélectionne',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                  ),
                ),

                SizedBox(height: 40),

                // Roue des émotions
                FutureBuilder<List<Emotion>>(
                  future: _emotionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
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
                        
                        final moodLog = await SupabaseService.createMoodLog(
                          emotionId: emotion.id,
                        );
                        
                        if (moodLog == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur lors de l\'enregistrement'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pushNamed(
                          context,
                          AppRoutes.context,
                          arguments: {
                            'emotionId': emotion.id,
                            'moodLogId': moodLog.id,
                          },
                        );
                      },
                    );
                  },
                ),
                
                SizedBox(height: 24),
                
                // Bouton Feedback
                Container(
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
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                _buildSleepLink(),
                
                SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSleepLink() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.sleep);
        },
        child: Text(
          "Aide au sommeil 🌙",
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
