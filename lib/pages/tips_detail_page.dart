import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/supabase_service.dart';
import '../models/tip.dart';
import '../models/instruction_step.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class TipsDetailPage extends StatefulWidget {
  final int tipId;
  final int? emotionId;

  TipsDetailPage({
    required this.tipId,
    this.emotionId,
  });

  @override
  _TipsDetailPageState createState() => _TipsDetailPageState();
}

class _TipsDetailPageState extends State<TipsDetailPage> {
  Future<Tip?>? _tipFuture;
  bool _isCreatingSession = false;
  
  // Audio player
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tipFuture = SupabaseService.getTip(widget.tipId);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initAudioPlayer(String audioUrl) async {
    _audioPlayer = AudioPlayer();
    
    try {
      await _audioPlayer!.setUrl(audioUrl);
      
      // Écouter les changements de durée
      _audioPlayer!.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() => _duration = duration);
        }
      });
      
      // Écouter les changements de position
      _audioPlayer!.positionStream.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });
      
      // Écouter les changements d'état
      _audioPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
    } catch (e) {
      print('Erreur lors du chargement audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement audio'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_audioPlayer == null) return;
    
    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play();
    }
  }

  Color _getCategoryColor(String category) {
    return AppColors.categories[category] ?? AppColors.primary;
  }

  IconData _getCategoryIconData(String category) {
    const icons = {
      'respiration': Icons.air_outlined,
      'mouvement': Icons.directions_run_outlined,
      'mental': Icons.psychology_outlined,
      'nutrition': Icons.restaurant_outlined,
      'musique': Icons.music_note_outlined,
    };
    return icons[category] ?? Icons.spa_outlined;
  }

  IconData _getStepIcon(String? iconName) {
    const icons = {
      'chair': Icons.chair_outlined,
      'hand': Icons.back_hand_outlined,
      'arrow_upward': Icons.arrow_upward,
      'arrow_downward': Icons.arrow_downward,
      'pause': Icons.pause_circle_outline,
      'refresh': Icons.refresh,
      'timer': Icons.timer_outlined,
      'person': Icons.person_outline,
      'favorite': Icons.favorite_outline,
      'visibility': Icons.visibility_outlined,
    };
    return icons[iconName] ?? Icons.check_circle_outline;
  }

  Future<void> _handleStartExercise(Tip tip) async {
    setState(() => _isCreatingSession = true);

    try {
      // Toujours créer un moodLog (avec emotion_id 1 par défaut si pas fourni)
      final moodLog = await SupabaseService.createMoodLog(
        emotionId: widget.emotionId ?? 1, // Défaut = Stress
      );

      if (moodLog == null) {
        throw Exception('Impossible de créer le mood log');
      }

      if (!mounted) return;

      // Créer la session avec le moodLogId
      final sessionId = await SupabaseService.createTipSession(
        tipId: tip.id!,
        moodLogId: moodLog.id!,
      );

      if (sessionId == null) {
        throw Exception('Impossible de créer la session');
      }

      if (!mounted) return;

      // Naviguer vers le player avec tip et sessionId
      Navigator.pushNamed(
        context,
        AppRoutes.tipsPlayer,
        arguments: {
          'tip': tip,
          'sessionId': sessionId,
        },
      );
    } catch (e) {
      print('❌ Erreur session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSession = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<Tip?>(
          future: _tipFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    SizedBox(height: 16),
                    Text('Erreur de chargement'),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Retour'),
                    ),
                  ],
                ),
              );
            }

            final tip = snapshot.data!;
            final color = _getCategoryColor(tip.category);
            final icon = _getCategoryIconData(tip.category);

            // Init audio player si audio disponible
            if (tip.hasAudioGuide && _audioPlayer == null) {
              _initAudioPlayer(tip.audioUrl!);
            }

            return CustomScrollView(
              slivers: [
                // AppBar
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: color,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, color.withOpacity(0.7)],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 80,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),

                // Contenu
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Header info
                      _buildHeaderSection(tip, color),

                      // Audio player si disponible
                      if (tip.hasAudioGuide)
                        _buildAudioPlayer(tip, color),

                      // Instructions détaillées si disponibles
                      if (tip.hasInstructions)
                        _buildInstructionsSection(tip, color),

                      // Description
                      _buildDescriptionSection(tip),

                      // Bienfaits
                      if (tip.description.contains('Bienfaits'))
                        _buildBenefitsSection(tip, color),

                      SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomSheet: FutureBuilder<Tip?>(
          future: _tipFuture,
          builder: (context, snapshot) {
            if (snapshot.data == null) return SizedBox.shrink();
            final tip = snapshot.data!;
            final color = _getCategoryColor(tip.category);

            return Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreatingSession
                        ? null
                        : () => _handleStartExercise(tip),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      disabledBackgroundColor: color.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isCreatingSession
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'Commencer l\'exercice',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Tip tip, Color color) {
    return Container(
      margin: EdgeInsets.all(24),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tip.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (tip.durationMinutes != null) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 16, color: color),
                      SizedBox(width: 4),
                      Text(
                        '${tip.durationMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: 16),

          // Titre
          Text(
            tip.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(Tip tip, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.headphones, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio guidé disponible',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Écoute la guidance vocale',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble() > 0
                  ? _duration.inSeconds.toDouble()
                  : 1.0,
              onChanged: (value) async {
                await _audioPlayer?.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),

          // Time labels
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Contrôles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () async {
                  final newPosition = _position - Duration(seconds: 10);
                  await _audioPlayer?.seek(
                    newPosition < Duration.zero ? Duration.zero : newPosition,
                  );
                },
                icon: Icon(Icons.replay_10, size: 32),
                color: color,
              ),
              SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _toggleAudio,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 16),
              IconButton(
                onPressed: () async {
                  final newPosition = _position + Duration(seconds: 10);
                  await _audioPlayer?.seek(
                    newPosition > _duration ? _duration : newPosition,
                  );
                },
                icon: Icon(Icons.forward_10, size: 32),
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection(Tip tip, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: color, size: 28),
              SizedBox(width: 12),
              Text(
                'Comment faire',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Liste des étapes
          ...tip.instructionsSteps!.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == tip.instructionsSteps!.length - 1;

            return _buildInstructionStep(step, color, isLast);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(InstructionStep step, Color color, bool isLast) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _getStepIcon(step.icon),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.5),
                        color.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 16),

          // Contenu de l'étape
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${step.step}. ${step.title}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step.durationFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  step.description,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMedium,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(Tip tip) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À propos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12),
          Text(
            tip.description,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textMedium,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(Tip tip, Color color) {
    // Parse benefits from description (simple version)
    final benefits = [
      'Réduit le stress et l\'anxiété',
      'Améliore la concentration',
      'Favorise la détente musculaire',
      'Aide à l\'endormissement',
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: color, size: 24),
              SizedBox(width: 12),
              Text(
                'Bienfaits',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...benefits.map((benefit) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        benefit,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMedium,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}