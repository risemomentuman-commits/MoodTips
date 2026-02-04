// lib/models/badge.dart
// Modèle de données pour les badges

import 'package:flutter/material.dart';

enum BadgeCategory {
  streak,      // Régularité
  exercise,    // Exercices
  exploration, // Découverte
  timing,      // Moments de la journée
  milestone,   // Jalons importants
}

enum BadgeLevel {
  bronze,
  silver,
  gold,
}

class Badge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final BadgeCategory category;
  final BadgeLevel level;
  final int requiredCount;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int currentProgress;
  
  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.level,
    required this.requiredCount,
    this.isUnlocked = false,
    this.unlockedAt,
    this.currentProgress = 0,
  });
  
  /// Pourcentage de progression (0-100)
  double get progressPercentage {
    if (isUnlocked) return 100.0;
    return (currentProgress / requiredCount * 100).clamp(0, 100);
  }
  
  /// Couleur selon le niveau
  Color get color {
    switch (level) {
      case BadgeLevel.bronze:
        return Color(0xFFCD7F32); // Bronze
      case BadgeLevel.silver:
        return Color(0xFFC0C0C0); // Argent
      case BadgeLevel.gold:
        return Color(0xFFFFD700); // Or
    }
  }
  
  /// Emoji selon la catégorie
  String get emoji {
    switch (category) {
      case BadgeCategory.streak:
        return '🔥';
      case BadgeCategory.exercise:
        return '💪';
      case BadgeCategory.exploration:
        return '🌟';
      case BadgeCategory.timing:
        return '⏰';
      case BadgeCategory.milestone:
        return '🏆';
    }
  }
  
  /// Convertir depuis JSON (simplifié)
  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: Icons.star, // Icon par défaut
      category: BadgeCategory.values.firstWhere(
        (e) => e.toString() == 'BadgeCategory.${json['category']}',
      ),
      level: BadgeLevel.values.firstWhere(
        (e) => e.toString() == 'BadgeLevel.${json['level']}',
      ),
      requiredCount: json['required_count'],
      isUnlocked: json['is_unlocked'] ?? false,
      unlockedAt: json['unlocked_at'] != null 
        ? DateTime.parse(json['unlocked_at'])
        : null,
      currentProgress: json['current_progress'] ?? 0,
    );
  }
  
  /// Convertir vers JSON (simplifié)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'level': level.toString().split('.').last,
      'required_count': requiredCount,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'current_progress': currentProgress,
    };
  }
  

  /// Copier avec modifications
  Badge copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentProgress,
  }) {
    return Badge(
      id: id,
      name: name,
      description: description,
      icon: icon,
      category: category,
      level: level,
      requiredCount: requiredCount,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }
}
