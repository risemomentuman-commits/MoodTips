import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/emotion.dart';
import '../utils/app_colors.dart';

class EmotionWheel extends StatefulWidget {
  final List<Emotion> emotions;
  final Function(Emotion) onEmotionSelected;

  const EmotionWheel({
    Key? key,
    required this.emotions,
    required this.onEmotionSelected,
  }) : super(key: key);

  @override
  _EmotionWheelState createState() => _EmotionWheelState();
}

class _EmotionWheelState extends State<EmotionWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  
  double _currentRotation = 0.0;
  double _targetRotation = 0.0;
  int _selectedIndex = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.addListener(() {
      setState(() {
        _currentRotation = _rotationAnimation.value;
      });
    });

    // Animation initiale (la roue tourne au démarrage)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playInitialAnimation();
    });
  }

  void _playInitialAnimation() async {
    // Faire 2 tours complets puis s'arrêter sur la première émotion
    final initialRotation = math.pi * 4; // 2 tours
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: initialRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _controller.duration = Duration(milliseconds: 2000);
    await _controller.forward(from: 0.0);
    
    _currentRotation = 0.0;
    _targetRotation = 0.0;
    _controller.duration = Duration(milliseconds: 300);
    setState(() {});
  }

  void _rotateToIndex(int index) {
    final anglePerEmotion = (2 * math.pi) / widget.emotions.length;
    final targetAngle = -index * anglePerEmotion;
    
    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    setState(() {
      _selectedIndex = index;
      _targetRotation = targetAngle;
    });

    _controller.forward(from: 0.0);
    
    // Haptic feedback léger
    HapticFeedback.lightImpact();
    
    // Son de sélection (optionnel, simple et léger)
    SystemSound.play(SystemSoundType.click);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      _isDragging = true;
    }

    final center = Offset(
      context.size!.width / 2,
      context.size!.height / 2,
    );

    final angle = math.atan2(
      details.localPosition.dy - center.dy,
      details.localPosition.dx - center.dx,
    );

    setState(() {
      _currentRotation += details.delta.dx * 0.01;
    });

    // Déterminer quelle émotion est la plus proche du haut
    final anglePerEmotion = (2 * math.pi) / widget.emotions.length;
    final normalizedRotation = _currentRotation % (2 * math.pi);
    final closestIndex = ((-normalizedRotation / anglePerEmotion).round()) % widget.emotions.length;

    if (closestIndex != _selectedIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = closestIndex;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    
    // Snap à l'émotion la plus proche
    final anglePerEmotion = (2 * math.pi) / widget.emotions.length;
    final targetAngle = -_selectedIndex * anglePerEmotion;
    
    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _targetRotation = targetAngle;
    _controller.forward(from: 0.0);
    
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  IconData _getEmotionIcon(String emotionName) {
    final icons = {
      // Positif
      'heureux': Icons.sentiment_very_satisfied_rounded,
      'joyeux': Icons.emoji_emotions_rounded,
      'calme': Icons.spa_rounded,
      'serein': Icons.self_improvement_rounded,
      'énergique': Icons.flash_on_rounded,
      'motivé': Icons.local_fire_department_rounded,
      'reconnaissant': Icons.favorite_rounded,
      'aimant': Icons.volunteer_activism_rounded,
      'content': Icons.sentiment_satisfied_alt_rounded,
      'paisible': Icons.water_drop_rounded,
      
      // Négatif
      'anxieux': Icons.psychology_alt_rounded,
      'inquiet': Icons.sentiment_dissatisfied_rounded,
      'triste': Icons.sentiment_very_dissatisfied_rounded,
      'mélancolique': Icons.cloud_rounded,
      'en colère': Icons.local_fire_department_rounded,
      'irrité': Icons.whatshot_rounded,
      'fatigué': Icons.nights_stay_rounded,
      'épuisé': Icons.battery_0_bar_rounded,
      'stressé': Icons.warning_amber_rounded,
      'dépassé': Icons.trending_down_rounded,
      
      // Neutre
      'confus': Icons.help_outline_rounded,
      'perdu': Icons.explore_off_rounded,
      'nostalgique': Icons.schedule_rounded,
      'pensif': Icons.cloud_queue_rounded,
    };
    
    return icons[emotionName.toLowerCase()] ?? Icons.sentiment_neutral_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wheelSize = math.min(size.width, size.height) * 0.75;

    return Column(
      children: [
        // Indicateur en haut (triangle pointant vers l'émotion sélectionnée)
        Container(
          margin: EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              Icon(
                Icons.arrow_drop_down,
                size: 48,
                color: AppColors.primary,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Text(
                  widget.emotions[_selectedIndex].name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Roue des émotions
        GestureDetector(
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Container(
            width: wheelSize,
            height: wheelSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercle de fond
                Container(
                  width: wheelSize,
                  height: wheelSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.05),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),

                // Émotions disposées en cercle
                ...List.generate(widget.emotions.length, (index) {
                  return _buildEmotionItem(
                    emotion: widget.emotions[index],
                    index: index,
                    totalCount: widget.emotions.length,
                    wheelSize: wheelSize,
                  );
                }),

                // Centre de la roue (décoratif)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 40),

        // Bouton de validation
        Container(
          width: 200,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              widget.onEmotionSelected(widget.emotions[_selectedIndex]);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Valider',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.check_circle, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionItem({
    required Emotion emotion,
    required int index,
    required int totalCount,
    required double wheelSize,
  }) {
    final anglePerEmotion = (2 * math.pi) / totalCount;
    final angle = index * anglePerEmotion + _currentRotation;
    
    final radius = wheelSize * 0.35;
    final x = radius * math.cos(angle - math.pi / 2);
    final y = radius * math.sin(angle - math.pi / 2);

    // Calculer la distance de cet item par rapport au haut (position sélectionnée)
    final distanceFromTop = (angle - math.pi / 2).abs() % (2 * math.pi);
    final normalizedDistance = math.min(distanceFromTop, 2 * math.pi - distanceFromTop);
    
    // Plus l'item est proche du haut, plus il est grand
    final scale = 1.0 - (normalizedDistance / math.pi) * 0.4;
    final opacity = 0.5 + (scale - 0.6) * 1.25;
    
    final isSelected = index == _selectedIndex;

    return Transform.translate(
      offset: Offset(x, y),
      child: GestureDetector(
        onTap: () => _rotateToIndex(index),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(scale),
          child: Opacity(
            opacity: opacity.clamp(0.3, 1.0),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.emotions[emotion.name.toLowerCase()]?.withOpacity(0.3) ?? AppColors.primary.withOpacity(0.3),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (AppColors.emotions[emotion.name.toLowerCase()] ?? AppColors.primary).withOpacity(0.2),
                    blurRadius: isSelected ? 15 : 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 64,  // ✅ Plus grand
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(  // ✅ Gradient pour plus de profondeur
                      colors: [
                        (AppColors.emotions[emotion.name.toLowerCase()] ?? AppColors.primary).withOpacity(0.3),
                        (AppColors.emotions[emotion.name.toLowerCase()] ?? AppColors.primary).withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [  // ✅ Ombre pour relief
                      BoxShadow(
                        color: (AppColors.emotions[emotion.name.toLowerCase()] ?? AppColors.primary).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getEmotionIcon(emotion.name),
                    size: 36,  // ✅ Plus grand
                    color: AppColors.emotions[emotion.name.toLowerCase()] ?? AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
