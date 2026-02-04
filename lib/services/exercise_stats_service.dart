// lib/services/exercise_stats_service.dart
// Récupère et analyse les stats des exercices complétés

import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciseStats {
  final int totalCompleted;
  final int betterCount;
  final int sameCount;
  final int worseCount;
  final double improvementRate; // Pourcentage "mieux"
  final List<TopExercise> topExercises;
  
  ExerciseStats({
    required this.totalCompleted,
    required this.betterCount,
    required this.sameCount,
    required this.worseCount,
    required this.improvementRate,
    required this.topExercises,
  });
}

class TopExercise {
  final String tipId;
  final String title;
  final int timesCompleted;
  final int betterCount;
  final double successRate;
  
  TopExercise({
    required this.tipId,
    required this.title,
    required this.timesCompleted,
    required this.betterCount,
    required this.successRate,
  });
}

class ExerciseStatsService {
  static final supabase = Supabase.instance.client;
  
  /// Récupérer les stats globales des exercices
  static Future<ExerciseStats?> getExerciseStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Récupérer toutes les sessions complétées avec feedback
      final response = await supabase
        .from('exercise_sessions')
        .select('post_exercise_feeling, tip_id')
        .eq('user_id', userId)
        .eq('completed', true)
        .not('post_exercise_feeling', 'is', null);
      
      if (response == null || response.isEmpty) {
        return ExerciseStats(
          totalCompleted: 0,
          betterCount: 0,
          sameCount: 0,
          worseCount: 0,
          improvementRate: 0,
          topExercises: [],
        );
      }
      
      // Compter les feedbacks
      int betterCount = 0;
      int sameCount = 0;
      int worseCount = 0;
      
      for (var session in response) {
        final feeling = session['post_exercise_feeling'];
        if (feeling == 'better') betterCount++;
        else if (feeling == 'same') sameCount++;
        else if (feeling == 'worse') worseCount++;
      }
      
      final total = response.length;
      final improvementRate = total > 0 ? (betterCount / total * 100) : 0;
      
      // Récupérer les top exercices
      final topExercises = await _getTopExercises(userId);
      
      return ExerciseStats(
        totalCompleted: total,
        betterCount: betterCount,
        sameCount: sameCount,
        worseCount: worseCount,
        improvementRate: improvementRate,
        topExercises: topExercises,
      );
      
    } catch (e) {
      print('❌ Erreur getExerciseStats: $e');
      return null;
    }
  }
  
  /// Récupérer les 3 exercices les plus efficaces
  static Future<List<TopExercise>> _getTopExercises(String userId) async {
    try {
      // Récupérer toutes les sessions groupées par tip_id
      final response = await supabase
        .from('exercise_sessions')
        .select('tip_id, post_exercise_feeling')
        .eq('user_id', userId)
        .eq('completed', true)
        .not('post_exercise_feeling', 'is', null);
      
      if (response == null || response.isEmpty) return [];
      
      // Grouper par tip_id
      Map<String, List<String>> tipFeedbacks = {};
      
      for (var session in response) {
        final tipId = session['tip_id'] as String;
        final feeling = session['post_exercise_feeling'] as String;
        
        if (!tipFeedbacks.containsKey(tipId)) {
          tipFeedbacks[tipId] = [];
        }
        tipFeedbacks[tipId]!.add(feeling);
      }
      
      // Calculer le taux de succès pour chaque exercice
      List<TopExercise> exercises = [];
      
      for (var entry in tipFeedbacks.entries) {
        final tipId = entry.key;
        final feedbacks = entry.value;
        
        final betterCount = feedbacks.where((f) => f == 'better').length;
        final timesCompleted = feedbacks.length;
        final successRate = (betterCount / timesCompleted * 100);
        
        // Récupérer le titre de l'exercice
        final tipResponse = await supabase
          .from('tips')
          .select('title')
          .eq('id', tipId)
          .single();
        
        final title = tipResponse['title'] ?? 'Exercice';
        
        exercises.add(TopExercise(
          tipId: tipId,
          title: title,
          timesCompleted: timesCompleted,
          betterCount: betterCount,
          successRate: successRate,
        ));
      }
      
      // Trier par taux de succès puis par nombre de fois complété
      exercises.sort((a, b) {
        final rateCompare = b.successRate.compareTo(a.successRate);
        if (rateCompare != 0) return rateCompare;
        return b.timesCompleted.compareTo(a.timesCompleted);
      });
      
      // Retourner top 3
      return exercises.take(3).toList();
      
    } catch (e) {
      print('❌ Erreur _getTopExercises: $e');
      return [];
    }
  }
}
