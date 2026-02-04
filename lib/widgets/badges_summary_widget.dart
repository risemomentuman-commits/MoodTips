// lib/widgets/badges_summary_widget.dart
// Widget résumé des badges pour le dashboard

import 'package:flutter/material.dart';
import '../models/badge.dart' as models;
import '../services/badge_service.dart';
import '../utils/app_colors.dart';

class BadgesSummaryWidget extends StatefulWidget {
  @override
  _BadgesSummaryWidgetState createState() => _BadgesSummaryWidgetState();
}

class _BadgesSummaryWidgetState extends State<BadgesSummaryWidget> {
  List<models.Badge> _badges = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadBadges();
  }
  
  Future<void> _loadBadges() async {
    final badges = await BadgeService.getUserBadges();
    if (mounted) {
      setState(() {
        _badges = badges;
        _isLoading = false;
      });
    }
  }
  
  int get _unlockedCount => _badges.where((b) => b.isUnlocked).length;
  
  List<models.Badge> get _recentBadges {
    final unlocked = _badges.where((b) => b.isUnlocked).toList();
    unlocked.sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    return unlocked.take(3).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox.shrink();
    }
    
    if (_unlockedCount == 0) {
      return SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/badges'),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFD700).withOpacity(0.2),
              Color(0xFFDAA520).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFFFFD700).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFD700).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events, color: Color(0xFFDAA520), size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tes badges',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '$_unlockedCount/${_badges.length} débloqués',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMedium),
              ],
            ),
            
            // Badges récents
            if (_recentBadges.isNotEmpty) ...[
              SizedBox(height: 16),
              Row(
                children: _recentBadges.map((badge) {
                  return Expanded(
                    child: _buildMiniBadge(badge),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMiniBadge(models.Badge badge) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _getBadgeGradient(badge.level),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(badge.icon, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
            badge.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  LinearGradient _getBadgeGradient(models.BadgeLevel level) {
    switch (level) {
      case models.BadgeLevel.bronze:
        return LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFFB8722C)]);
      case models.BadgeLevel.silver:
        return LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFA8A8A8)]);
      case models.BadgeLevel.gold:
        return LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFDAA520)]);
    }
  }
}
