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
  int? _selectedIndex;
  bool _isCreatingMoodLog = false;
  
  @override
  void initState() {
    super.initState();
    _emotionsFuture = SupabaseService.getEmotions();
  }

  Future<void> _handleEmotionTap(Emotion emotion, int index) async {
    setState(() => _selectedIndex = index);
    
    // Attendre un peu pour l'animation
    await Future.delayed(Duration(milliseconds: 400));
    
    if (!mounted) return;
    
    _handleEmotionSelect(emotion);
  }

  Future<void> _handleEmotionSelect(Emotion emotion) async {
    setState(() => _isCreatingMoodLog = true);

    try {
      // Créer le mood log
      final moodLog = await SupabaseService.createMoodLog(
        emotionId: emotion.id,
      );

      if (moodLog == null) {
        throw Exception('Impossible de créer le mood log');
      }

      if (!mounted) return;

      // Naviguer vers la page de contexte
      Navigator.pushNamed(
        context,
        AppRoutes.context,
        arguments: {
          'emotionId': emotion.id,
          'moodLogId': moodLog.id,
        },
      );
    } catch (e) {
      print('Erreur mood log: $e');
      if (!mounted) return;
      setState(() => _selectedIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingMoodLog = false);
      }
    }
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

            // ✅ NOUVELLE ROUE DES ÉMOTIONS (remplace GridView)
            Expanded(
              child: FutureBuilder<List<Emotion>>(
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
                      
                      // ✅ NOUVEAU : Créer le mood log d'abord
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
                      
                      // Navigation avec les 2 paramètres
                      Navigator.pushNamed(
                        context,
                        AppRoutes.context,
                        arguments: {
                          'emotionId': emotion.id,
                          'moodLogId': moodLog.id,  // ✅ Maintenant on a les deux
                        },
                      );
                    },
                  );
                },
              ),
            ),
            
                              // ✅ BOUTON FEEDBACK
                        Container(
                          margin: EdgeInsets.only(right: 16, top: 8),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final url = 'https://docs.google.com/forms/d/e/1FAIpQLSd5GIhsTxsvTGQULpspFzYboTV3jKXCG8ymRTSU4EYQdOlpUQ/viewform?	usp=publish-editor';
                                
                              // Ouvrir le lien
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
              _buildSleepLink(),

            ],
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
          "Aide au sommeil",
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// ✅ WIDGET CARTE D'ÉMOTION - VERSION COMPACTE
class _EmotionCard extends StatefulWidget {
  final Emotion emotion;
  final int index;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _EmotionCard({
    required this.emotion,
    required this.index,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_EmotionCard> createState() => _EmotionCardState();
}

class _EmotionCardState extends State<_EmotionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (widget.index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: animValue,
          child: Opacity(
            opacity: animValue,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.identity()
                  ..scale(_isPressed ? 0.95 : (widget.isSelected ? 0.98 : 1.0)),
                decoration: BoxDecoration(
                  gradient: widget.isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.color,
                            widget.color.withOpacity(0.7),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            widget.color.withOpacity(0.05),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(20), // ✅ RÉDUIT : 20 au lieu de 24
                  border: Border.all(
                    color: widget.isSelected
                        ? widget.color.withOpacity(0.5)
                        : widget.color.withOpacity(0.2),
                    width: widget.isSelected ? 2.5 : 1.5, // ✅ RÉDUIT : bordures plus fines
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isSelected
                          ? widget.color.withOpacity(0.3)  // ✅ RÉDUIT : ombre plus subtile
                          : widget.color.withOpacity(0.1), // ✅ RÉDUIT
                      blurRadius: widget.isSelected ? 20 : 12, // ✅ RÉDUIT
                      offset: Offset(0, widget.isSelected ? 8 : 4), // ✅ RÉDUIT
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Emoji avec animation de rotation sur sélection
                    AnimatedRotation(
                      turns: widget.isSelected ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      child: Text(
                        widget.emotion.emoji,
                        style: TextStyle(
                          fontSize: widget.isSelected ? 54 : 44, // ✅ RÉDUIT : 48/54 au lieu de 64/72
                          height: 1.0,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 8), // ✅ RÉDUIT : 8 au lieu de 12
                    
                    // Nom de l'émotion
                    Text(
                      widget.emotion.name,
                      style: TextStyle(
                        fontSize: 15, // ✅ RÉDUIT : 15 au lieu de 18
                        fontWeight: FontWeight.bold,
                        color: widget.isSelected
                            ? Colors.white
                            : AppColors.textDark,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    // Indicateur de sélection
                    if (widget.isSelected) ...[
                      SizedBox(height: 6), // ✅ RÉDUIT : 6 au lieu de 8
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        width: 32, // ✅ RÉDUIT : 32 au lieu de 40
                        height: 3,  // ✅ RÉDUIT : 3 au lieu de 4
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

