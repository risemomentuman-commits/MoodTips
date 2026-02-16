// lib/services/badge_service.dart
// Service de gestion des badges

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/badge.dart' as models;

class BadgeService {
  static final supabase = Supabase.instance.client;
  
  /// Liste des badges disponibles (définis en dur)
  static final List<models.Badge> allBadges = [
    // ===== STREAK BADGES =====
    models.Badge(
      id: 'streak_3',
      name: 'Premier pas',
      description: '3 jours consécutifs',
      icon: Icons.local_fire_department,
      category: models.BadgeCategory.streak,
      level: models.BadgeLevel.bronze,
      requiredCount: 3,
    ),
    models.Badge(
      id: 'streak_7',
      name: 'Une semaine',
      description: '7 jours consécutifs',
      icon: Icons.local_fire_department,
      category: models.BadgeCategory.streak,
      level: models.BadgeLevel.silver,
      requiredCount: 7,
    ),
    models.Badge(
      id: 'streak_30',
      name: 'Un mois',
      description: '30 jours consécutifs',
      icon: Icons.local_fire_department,
      category: models.BadgeCategory.streak,
      level: models.BadgeLevel.gold,
      requiredCount: 30,
    ),
    
    // ===== EXERCISE BADGES =====
    models.Badge(
      id: 'exercise_5',
      name: 'Débutant',
      description: '5 exercices complétés',
      icon: Icons.fitness_center,
      category: models.BadgeCategory.exercise,
      level: models.BadgeLevel.bronze,
      requiredCount: 5,
    ),
    models.Badge(
      id: 'exercise_25',
      name: 'Pratiquant',
      description: '25 exercices complétés',
      icon: Icons.fitness_center,
      category: models.BadgeCategory.exercise,
      level: models.BadgeLevel.silver,
      requiredCount: 25,
    ),
    models.Badge(
      id: 'exercise_100',
      name: 'Expert',
      description: '100 exercices complétés',
      icon: Icons.fitness_center,
      category: models.BadgeCategory.exercise,
      level: models.BadgeLevel.gold,
      requiredCount: 100,
    ),
    
    // ===== EXPLORATION BADGES =====
    models.Badge(
      id: 'explore_categories',
      name: 'Explorateur',
      description: 'Tester toutes les catégories',
      icon: Icons.explore,
      category: models.BadgeCategory.exploration,
      level: models.BadgeLevel.silver,
      requiredCount: 4, // 4 catégories
    ),
    models.Badge(
      id: 'positive_week',
      name: 'Optimiste',
      description: '7 émotions positives d\'affilée',
      icon: Icons.sentiment_very_satisfied,
      category: models.BadgeCategory.exploration,
      level: models.BadgeLevel.gold,
      requiredCount: 7,
    ),
    
    // ===== TIMING BADGES =====
    models.Badge(
      id: 'early_bird',
      name: 'Lève-tôt',
      description: 'Check-in avant 8h',
      icon: Icons.wb_sunny,
      category: models.BadgeCategory.timing,
      level: models.BadgeLevel.bronze,
      requiredCount: 1,
    ),
    models.Badge(
      id: 'night_owl',
      name: 'Couche-tard',
      description: 'Check-in après 22h',
      icon: Icons.nightlight,
      category: models.BadgeCategory.timing,
      level: models.BadgeLevel.bronze,
      requiredCount: 1,
    ),
    
    // ===== MILESTONE BADGES =====
    models.Badge(
      id: 'first_checkin',
      name: 'Bienvenue',
      description: 'Premier check-in',
      icon: Icons.waving_hand,
      category: models.BadgeCategory.milestone,
      level: models.BadgeLevel.bronze,
      requiredCount: 1,
    ),
    models.Badge(
      id: 'checkin_50',
      name: 'Fidèle',
      description: '50 check-ins',
      icon: Icons.favorite,
      category: models.BadgeCategory.milestone,
      level: models.BadgeLevel.silver,
      requiredCount: 50,
    ),
    models.Badge(
      id: 'checkin_100',
      name: 'Légende',
      description: '100 check-ins',
      icon: Icons.emoji_events,
      category: models.BadgeCategory.milestone,
      level: models.BadgeLevel.gold,
      requiredCount: 100,
    ),
  ];
  
  /// Récupérer les badges de l'utilisateur avec leur progression
  static Future<List<models.Badge>> getUserBadges() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];
      
      // Récupérer les badges débloqués
      final response = await supabase
        .from('user_badges')
        .select('badge_id, unlocked_at')
        .eq('user_id', userId);
      
      final unlockedBadges = Map<String, DateTime>.fromEntries(
        (response as List).map((row) => MapEntry(
          row['badge_id'] as String,
          DateTime.parse(row['unlocked_at']),
        )),
      );
      
      // Calculer la progression pour chaque badge
      List<models.Badge> badges = [];
      
      for (var badge in allBadges) {
        final isUnlocked = unlockedBadges.containsKey(badge.id);
        final progress = await _calculateProgress(badge);
        
        badges.add(badge.copyWith(
          isUnlocked: isUnlocked,
          unlockedAt: unlockedBadges[badge.id],
          currentProgress: progress,
        ));
      }
      
      return badges;
      
    } catch (e) {
      print('❌ Erreur getUserBadges: $e');
      return [];
    }
  }
  
  /// Calculer la progression pour un badge
  static Future<int> _calculateProgress(models.Badge badge) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;
      
      switch (badge.id) {
        // Streaks
        case 'streak_3':
        case 'streak_7':
        case 'streak_30':
          return await _getCurrentStreak();
        
        // Exercices
        case 'exercise_5':
        case 'exercise_25':
        case 'exercise_100':
          return await _getCompletedExercises();
        
        // Check-ins
        case 'first_checkin':
        case 'checkin_50':
        case 'checkin_100':
          return await _getTotalCheckIns();
        
        // Catégories explorées
        case 'explore_categories':
          return await _getExploredCategories();
        
        // Émotions positives
        case 'positive_week':
          return await _getConsecutivePositiveEmotions();
        
        // Timing badges (1 seul suffit)
        case 'early_bird':
        case 'night_owl':
          return await _hasTimingBadge(badge.id);
        
        default:
          return 0;
      }
      
    } catch (e) {
      print('❌ Erreur _calculateProgress: $e');
      return 0;
    }
  }
  
  /// Helper: Streak actuel
  static Future<int> _getCurrentStreak() async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
      .from('profiles')
      .select('current_streak')
      .eq('id', userId!)
      .single();
    return response['current_streak'] ?? 0;
  }
  
  /// Helper: Exercices complétés
  static Future<int> _getCompletedExercises() async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
      .from('tips_sessions')
      .select()
      .eq('user_id', userId!)
      .eq('completed', true);
    return (response as List).length;
  }
  
  /// Helper: Total check-ins
  static Future<int> _getTotalCheckIns() async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
      .from('mood_logs')
      .select()
      .eq('user_id', userId!);
    return (response as List).length;
  }
  
  /// Helper: Catégories explorées
  static Future<int> _getExploredCategories() async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
      .from('tips_sessions')
      .select('tip_id')
      .eq('user_id', userId!)
      .eq('completed', true);
    
    // Récupérer les catégories des tips
    final tipIds = (response as List).map((e) => e['tip_id']).toSet();
    if (tipIds.isEmpty) return 0;
    
    final tipsResponse = await supabase
      .from('tips')
      .select('category')
      .inFilter('id', tipIds.toList());
    
    final categories = (tipsResponse as List)
      .map((e) => e['category'])
      .toSet();
    
    return categories.length;
  }
  
  /// Helper: Émotions positives consécutives
  static Future<int> _getConsecutivePositiveEmotions() async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
      .from('mood_logs')
      .select('emotion_id, emotions(name)')
      .eq('user_id', userId!)
      .order('created_at', ascending: false)
      .limit(10);

    final positiveEmotions = ['joyeux', 'heureux', 'calme', 'confiant', 'énergique'];
    int consecutive = 0;

    for (var log in response) {
      final emotion = log['emotions']?['name'] as String?;
      if (emotion != null && positiveEmotions.contains(emotion.toLowerCase())) {
        consecutive++;
      } else {
        break;
      }
    }
    return consecutive;
  }
  
  /// Helper: Badge timing (early bird / night owl)
  static Future<int> _hasTimingBadge(String badgeId) async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
      .from('mood_logs')
      .select('created_at')
      .eq('user_id', userId!)
      .order('created_at', ascending: false)
      .limit(50);
    
    for (var log in response) {
      final time = DateTime.parse(log['created_at']);
      final hour = time.hour;
      
      if (badgeId == 'early_bird' && hour < 8) return 1;
      if (badgeId == 'night_owl' && hour >= 22) return 1;
    }
    
    return 0;
  }
  
  /// Vérifier et débloquer les nouveaux badges
  static Future<List<models.Badge>> checkAndUnlockBadges() async {
    try {
      final badges = await getUserBadges();
      final newlyUnlocked = <models.Badge>[];
      
      for (var badge in badges) {
        // Si déjà débloqué, skip
        if (badge.isUnlocked) continue;
        
        // Si progression atteinte, débloquer
        if (badge.currentProgress >= badge.requiredCount) {
          await _unlockBadge(badge.id);
          newlyUnlocked.add(badge.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          ));
        }
      }
      
      return newlyUnlocked;
      
    } catch (e) {
      print('❌ Erreur checkAndUnlockBadges: $e');
      return [];
    }
  }
  
  /// Débloquer un badge
  static Future<void> _unlockBadge(String badgeId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      await supabase.from('user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'unlocked_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Badge débloqué: $badgeId');
      
    } catch (e) {
      print('❌ Erreur _unlockBadge: $e');
    }
  }
}