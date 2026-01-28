import 'package:flutter/material.dart';
import '../services/edge_tts_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/tip.dart';
import '../models/instruction_step.dart';
import '../utils/app_colors.dart';
import '../services/supabase_service.dart';
import '../services/audio_preloader.dart';
 

class TipsPlayerPage extends StatefulWidget {
  final Tip tip;
  final int sessionId;

  const TipsPlayerPage({
    Key? key,
    required this.tip,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<TipsPlayerPage> createState() => _TipsPlayerPageState();
}

class _TipsPlayerPageState extends State<TipsPlayerPage> with TickerProviderStateMixin {
  int _currentStepIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isPlaying = false;
  bool _isCompleted = false;
  
  // TTS et Audio
  AudioPlayer? _backgroundMusicPlayer;
  bool _isSpeaking = false;
  double _musicVolume = 0.3;
  bool _hasSpokenFirstStep = false; // ✅ NOUVEAU: Pour éviter la répétition
  
  // Animations
  late AnimationController _breatheController;
  late AnimationController _progressController;
  late Animation<double> _breatheAnimation;
  
  List<InstructionStep> _steps = [];
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    EdgeTtsService.initialize();  // ← AJOUTE CETTE LIGNE

    print('🎬 initState appelé');

    print('✅ EdgeTTS initialisé');  // ← AJOUTE

    _initializeSteps();
    _initializeMusic();
    _initializeAnimations();
    _startTime = DateTime.now();
  }

  void _initializeSteps() {
    if (widget.tip.instructionsSteps != null && widget.tip.instructionsSteps!.isNotEmpty) {
      _steps = widget.tip.instructionsSteps!;
    } else {
      _steps = [
        InstructionStep(
          step: 1,
          title: widget.tip.title,
          description: widget.tip.description,
          duration: ((widget.tip.durationMinutes ?? 3) * 60).toInt(),
        ),
      ];
    }
    
    if (_steps.isNotEmpty) {
      _remainingSeconds = _steps[0].duration;
    }
  }

  
  void _initializeMusic() async {
    try {
      if (widget.tip.backgroundMusic != null && widget.tip.backgroundMusic!.isNotEmpty) {
        final musicFile = '${widget.tip.backgroundMusic}.mp3';
        
        _backgroundMusicPlayer = AudioPlayer();
        await _backgroundMusicPlayer!.setReleaseMode(ReleaseMode.loop);
        await _backgroundMusicPlayer!.setVolume(_musicVolume);
        await _backgroundMusicPlayer!.setSource(AssetSource('audio/$musicFile'));
        
        print('🎵 Musique prête : $musicFile');
      }
    } catch (e) {
      print("❌ Erreur musique: $e");
    }
  }

  void _initializeAnimations() {
    _breatheController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _breatheAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
    
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  Future<void> _speakCurrentStep() async {
    print('🎙️ _speakCurrentStep APPELÉ');

    final step = _steps[_currentStepIndex];
    String textToSpeak = "${step.title}. ${step.description}";

    print('🎙️ Texte: $textToSpeak');
    
    setState(() => _isSpeaking = true);
    try {
      await EdgeTtsService.speak(textToSpeak);
    } catch (e) {
    print('Erreur: $e');
    }
    setState(() => _isSpeaking = false);  // ← Doit être là !
    print('🗣️ Voix lancée: ${step.title}');
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseExercise();
    } else {
      _startExercise();
    }
  }

  void _startExercise() async {
    setState(() => _isPlaying = true);

    // Lancer la voix automatiquement
    await _speakCurrentStep();
    
    // ✅ Lancer la musique AVANT la voix
    if (_backgroundMusicPlayer != null) {
      try {
        await _backgroundMusicPlayer!.play(
          _backgroundMusicPlayer!.source!,
        );
        print('🎵 Musique lancée');
      } catch (e) {
        print('❌ Erreur lecture musique: $e');
      }
    }
       
    // Démarrer le timer
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _nextStep();
          }
        });
      }
    });
  }

  void _pauseExercise() {
    setState(() => _isPlaying = false);
    _timer?.cancel();
    setState(() => _isSpeaking = false);
    _backgroundMusicPlayer?.pause();
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _remainingSeconds = _steps[_currentStepIndex].duration;
        _progressController.forward(from: 0.0);
      });
      
      if (_isPlaying) {
        _speakCurrentStep();
      }
    } else {
      _completeExercise();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      _pauseExercise();
      setState(() {
        _currentStepIndex--;
        _remainingSeconds = _steps[_currentStepIndex].duration;
        _progressController.forward(from: 0.0);
      });
    }
  }

  void _completeExercise() async {
    _timer?.cancel();
        
    // ✅ FADE OUT de la musique sur 2 secondes
    if (_backgroundMusicPlayer != null) {
      await _fadeOutMusic();
    }
    
    setState(() {
      _isPlaying = false;
      _isCompleted = true;
    });
    
    // Enregistrer la session
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    await SupabaseService.completeTipSession(
      sessionId: widget.sessionId,
      durationSeconds: duration,
    );
    
    // Incrémenter les stats
    await SupabaseService.incrementStats(
      category: widget.tip.category,
      duration: duration,
    );
    
    // ✅ Afficher le feedback dialog
    await _showFeedbackDialog();
    
    if (!mounted) return;
    
    // Retour
    Navigator.pop(context, true);
  }

  // ✅ NOUVEAU: Fade out progressif de la musique
  Future<void> _fadeOutMusic() async {
    if (_backgroundMusicPlayer == null) return;
    
    const steps = 20; // 20 étapes
    const duration = 2000; // 2 secondes
    const stepDuration = duration ~/ steps;
    
    for (int i = steps; i >= 0; i--) {
      final volume = (_musicVolume * i / steps);
      await _backgroundMusicPlayer!.setVolume(volume);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
    
    await _backgroundMusicPlayer!.stop();
    await _backgroundMusicPlayer!.setVolume(_musicVolume); // Reset pour la prochaine fois
  }

  // ========== FEEDBACK POST-EXERCICE ==========
  
  Future<void> _showFeedbackDialog() async {
    String? selectedFeeling;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.secondary.withOpacity(0.05),
                      ],
                    ),
                  ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icône
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.celebration,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    Text(
                      'Bravo ! 🎉',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Text(
                      'Comment te sens-tu maintenant ?',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 32),
                    
                    // 3 Emojis
                    
                      // 3 Emojis
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: _buildFeelingOption(
                              emoji: '😊',
                              label: 'Mieux',
                              value: 'better',
                              isSelected: selectedFeeling == 'better',
                              onTap: () => setState(() => selectedFeeling = 'better'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: _buildFeelingOption(
                              emoji: '😐',
                              label: 'Pareil',
                              value: 'same',
                              isSelected: selectedFeeling == 'same',
                              onTap: () => setState(() => selectedFeeling = 'same'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: _buildFeelingOption(
                              emoji: '😔',
                              label: 'Moins bien',
                              value: 'worse',
                              isSelected: selectedFeeling == 'worse',
                              onTap: () => setState(() => selectedFeeling = 'worse'),
                            ),
                          ),
                        ],
                      ),
                    
                    SizedBox(height: 32),
                    
                    // Bouton
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: selectedFeeling == null
                            ? null
                            : () async {
                                await _saveFeedback(selectedFeeling!);
                                Navigator.of(context).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Continuer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            );
                      },
        );
      },
    );
  }

  Widget _buildFeelingOption({
    required String emoji,
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 90,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppColors.primaryGradient
              : LinearGradient(colors: [Colors.white, Colors.white]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 40),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFeedback(String feeling) async {
    try {
      final feedbackValue = {
        'better': 1,
        'same': 0,
        'worse': -1,
      }[feeling];

      await SupabaseService.updateSession(
        widget.sessionId,
        {
          'post_exercise_feeling': feeling,
          'feeling_improvement': feedbackValue,
        },
      );
      
      print('✅ Feedback enregistré : $feeling');
    } catch (e) {
      print('❌ Erreur feedback : $e');
    }
  }

  // ========== UI BUILD ==========

  Color _getCategoryColor() {
    return AppColors.categories[widget.tip.category] ?? AppColors.primary;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _backgroundMusicPlayer?.dispose();
    _breatheController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();
    final currentStep = _steps[_currentStepIndex];
    final progress = _currentStepIndex / _steps.length;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              categoryColor,
              categoryColor.withOpacity(0.7),
              categoryColor.withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(  // ✅ AJOUT
            child: Column(
              children: [
                _buildHeader(categoryColor),
                SizedBox(height: 40),
                _buildStepsProgress(progress),
                SizedBox(height: 40),
                _buildBreathingCircle(categoryColor),
                SizedBox(height: 40),
                _buildInstructionCard(currentStep, categoryColor),
                SizedBox(height: 60),  // ✅ Remplacer Spacer()
                _buildTimer(),
                SizedBox(height: 24),
                _buildControls(categoryColor),
                SizedBox(height: 80),  // ✅ Espace en bas
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color categoryColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => _showExitDialog(),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              widget.tip.category.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _musicVolume > 0 ? Icons.music_note : Icons.music_off,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () => _toggleMusic(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsProgress(double progress) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Étape ${_currentStepIndex + 1} sur ${_steps.length}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingCircle(Color categoryColor) {
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPlaying ? _breatheAnimation.value : 1.0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getCategoryIcon(),
                    size: 64,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isPlaying ? 'EN COURS' : 'PRÊT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionCard(InstructionStep step, Color categoryColor) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(_currentStepIndex),
        margin: EdgeInsets.symmetric(horizontal: 30),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.volume_off : Icons.volume_up,
                    color: categoryColor,
                  ),
                  onPressed: _speakCurrentStep,
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              step.description,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppColors.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    
    return Column(
      children: [
        Text(
          'TEMPS RESTANT',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(Color categoryColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: Icons.skip_previous,
            onPressed: _currentStepIndex > 0 ? _previousStep : null,
            size: 48,
          ),
          SizedBox(width: 24),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
                color: categoryColor,
              ),
            ),
          ),
          SizedBox(width: 24),
          _buildControlButton(
            icon: Icons.skip_next,
            onPressed: _currentStepIndex < _steps.length - 1 ? _nextStep : null,
            size: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(onPressed != null ? 0.3 : 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: size * 0.5),
        onPressed: onPressed,
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.tip.category) {
      case 'respiration':
        return Icons.air;
      case 'mouvement':
        return Icons.directions_run;
      case 'mental':
        return Icons.psychology;
      case 'musique':
        return Icons.music_note;
      default:
        return Icons.favorite;
    }
  }

  void _toggleMusic() {
    setState(() {
      if (_musicVolume > 0) {
        _musicVolume = 0;
        _backgroundMusicPlayer?.setVolume(0);
        _pauseExercise();
      } else {
        _musicVolume = 0.3;
        _backgroundMusicPlayer?.setVolume(0.3);
        _startExercise();
      }
    });
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitter l\'exercice ?'),
        content: Text('Es-tu sûr(e) de vouloir arrêter maintenant ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continuer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Quitter'),
          ),
        ],
      ),
    );
  }
}
