// lib/pages/badges_page.dart
// Page affichant tous les badges de l'utilisateur

import 'package:flutter/material.dart';
import '../models/badge.dart' as models;
import '../services/badge_service.dart';
import '../widgets/badge_card.dart';
import '../utils/app_colors.dart';

class BadgesPage extends StatefulWidget {
  @override
  _BadgesPageState createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  List<models.Badge> _badges = [];
  bool _isLoading = true;
  models.BadgeCategory? _selectedCategory;
  
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
  
  List<models.Badge> get _filteredBadges {
    if (_selectedCategory == null) return _badges;
    return _badges.where((b) => b.category == _selectedCategory).toList();
  }
  
  int get _unlockedCount => _badges.where((b) => b.isUnlocked).length;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mes Badges',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : Column(
            children: [
              // Stats header
              Container(
                margin: EdgeInsets.all(20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.streakGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(
                      value: '$_unlockedCount',
                      label: 'Débloqués',
                      icon: Icons.emoji_events,
                    ),
                    Container(width: 1, height: 50, color: Colors.white30),
                    _buildStat(
                      value: '${_badges.length}',
                      label: 'Total',
                      icon: Icons.star,
                    ),
                    Container(width: 1, height: 50, color: Colors.white30),
                    _buildStat(
                      value: '${(_unlockedCount / _badges.length * 100).toInt()}%',
                      label: 'Complété',
                      icon: Icons.trending_up,
                    ),
                  ],
                ),
              ),
              
              // Filtres catégories
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildFilterChip('Tous', null),
                    SizedBox(width: 8),
                    _buildFilterChip('🔥 Streak', models.BadgeCategory.streak),
                    SizedBox(width: 8),
                    _buildFilterChip('💪 Exercices', models.BadgeCategory.exercise),
                    SizedBox(width: 8),
                    _buildFilterChip('🌟 Exploration', models.BadgeCategory.exploration),
                    SizedBox(width: 8),
                    _buildFilterChip('⏰ Timing', models.BadgeCategory.timing),
                    SizedBox(width: 8),
                    _buildFilterChip('🏆 Milestones', models.BadgeCategory.milestone),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Liste des badges
              Expanded(
                child: _filteredBadges.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun badge dans cette catégorie',
                        style: TextStyle(color: AppColors.textMedium),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredBadges.length,
                      itemBuilder: (context, index) {
                        return BadgeCard(badge: _filteredBadges[index]);
                      },
                    ),
              ),
            ],
          ),
    );
  }
  
  Widget _buildStat({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilterChip(String label, models.BadgeCategory? category) {
    final isSelected = _selectedCategory == category;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
            ? AppColors.primaryGradient
            : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected ? AppColors.cardShadow : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
