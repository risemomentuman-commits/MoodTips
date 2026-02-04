// lib/widgets/badge_unlock_dialog.dart
// Dialog animé pour célébrer un nouveau badge

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/badge.dart' as models;
import '../utils/app_colors.dart';

class BadgeUnlockDialog extends StatefulWidget {
  final models.Badge badge;
  
  const BadgeUnlockDialog({
    Key? key,
    required this.badge,
  }) : super(key: key);

  @override
  _BadgeUnlockDialogState createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confettis en arrière-plan
          ...List.generate(20, (index) => _buildConfetti(index)),
          
          // Card principal
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge icon animé
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: _getBadgeGradient(),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.badge.color.withOpacity(0.4),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.badge.icon,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Texte célébration
                  Text(
                    '🎉 Nouveau Badge ! 🎉',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Nom badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: _getBadgeGradient(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.badge.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Description
                  Text(
                    widget.badge.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Bouton fermer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Super ! 💪',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfetti(int index) {
    final random = math.Random(index);
    final size = 8.0 + random.nextDouble() * 8;
    final startX = random.nextDouble() * 400 - 200;
    final endY = 200.0 + random.nextDouble() * 200;
    final duration = 800 + random.nextInt(400);
    final delay = random.nextInt(200);
    
    final colors = [
      Color(0xFFFFD700),
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFF95E1D3),
      Color(0xFFFFA07A),
    ];
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -100.0, end: endY),
      duration: Duration(milliseconds: duration),
      curve: Curves.easeIn,
      builder: (context, value, child) {
        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + startX,
          top: value,
          child: Opacity(
            opacity: 1 - (value / endY),
            child: Transform.rotate(
              angle: value * 0.05,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  LinearGradient _getBadgeGradient() {
    switch (widget.badge.level) {
      case models.BadgeLevel.bronze:
        return LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFFB8722C)],
        );
      case models.BadgeLevel.silver:
        return LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFFA8A8A8)],
        );
      case models.BadgeLevel.gold:
        return LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
        );
    }
  }
}
