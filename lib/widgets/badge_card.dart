// lib/widgets/badge_card.dart
// Card pour afficher un badge

import 'package:flutter/material.dart';
import '../models/badge.dart' as models;
import '../utils/app_colors.dart';

class BadgeCard extends StatelessWidget {
  final models.Badge badge;
  final VoidCallback? onTap;
  
  const BadgeCard({
    Key? key,
    required this.badge,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLocked = !badge.isUnlocked;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isLocked 
            ? LinearGradient(colors: [Colors.grey[300]!, Colors.grey[400]!])
            : _getBadgeGradient(),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isLocked ? 0.05 : 0.15),
              blurRadius: isLocked ? 5 : 10,
              offset: Offset(0, isLocked ? 2 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                badge.icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            
            SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Badge niveau
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getLevelText(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 4),
                  
                  Text(
                    badge.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Barre de progression
                  if (isLocked) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: badge.progressPercentage / 100,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${badge.currentProgress}/${badge.requiredCount}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Débloqué ${_formatDate(badge.unlockedAt!)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  LinearGradient _getBadgeGradient() {
    switch (badge.level) {
      case models.BadgeLevel.bronze:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCD7F32), Color(0xFFB8722C)],
        );
      case models.BadgeLevel.silver:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC0C0C0), Color(0xFFA8A8A8)],
        );
      case models.BadgeLevel.gold:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
        );
    }
  }
  
  String _getLevelText() {
    switch (badge.level) {
      case models.BadgeLevel.bronze:
        return 'Bronze';
      case models.BadgeLevel.silver:
        return 'Argent';
      case models.BadgeLevel.gold:
        return 'Or';
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'aujourd\'hui';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'il y a ${(diff.inDays / 7).floor()} semaines';
    return 'le ${date.day}/${date.month}/${date.year}';
  }
}
