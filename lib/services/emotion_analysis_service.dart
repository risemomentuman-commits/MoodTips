// lib/services/emotion_analysis_service.dart

import '../models/mood_log.dart';
import '../models/emotion.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmotionAnalysisService {
  
  /// Analyse les émotions récentes et retourne un niveau d'alerte
  /// 0 = Tout va bien
  /// 1 = Alerte légère (3-4 émotions négatives)
  /// 2 = Alerte modérée (5-7 émotions négatives)
  /// 3 = Alerte forte (8+ émotions négatives)
  static Future<Map<String, dynamic>> analyzeRecentEmotions() async {
    try {
      // Récupérer les 10 dernières émotions
      final moods = await SupabaseService.getMoodLogs(limit: 10);
      
      if (moods.isEmpty) {
        return {
          'alertLevel': 0,
          'consecutiveNegative': 0,
          'message': null,
          'shouldShow': false,
        };
      }
      
      // Compter les émotions négatives consécutives
      int consecutiveNegative = 0;
      
      for (var mood in moods) {
        // Émotions négatives : ID 6-10 (tristesse, anxiété, colère, etc.)
        // Émotions positives : ID 1-5 (joie, calme, excitation, etc.)
        if (mood.emotionId >= 6) {
          consecutiveNegative++;
        } else {
          break; // Arrête dès qu'on trouve une émotion positive
        }
      }
      
      // Déterminer le niveau d'alerte
      int alertLevel = 0;
      String? message;
      String? action;
      bool shouldShow = false;
      
      if (consecutiveNegative >= 8) {
        // Alerte FORTE
        alertLevel = 3;
        shouldShow = true;
        message = "On remarque que tu traverses un moment particulièrement difficile. "
                  "Prendre soin de toi est important. N'hésite pas à en parler à quelqu'un de confiance.";
        action = "strong";
        
      } else if (consecutiveNegative >= 5) {
        // Alerte MODÉRÉE
        alertLevel = 2;
        shouldShow = true;
        message = "Tu te sens moins bien ces derniers jours. "
                  "Veux-tu essayer un exercice qui pourrait t'aider ?";
        action = "exercise";
        
      } else if (consecutiveNegative >= 3) {
        // Alerte LÉGÈRE
        alertLevel = 1;
        shouldShow = true;
        message = "On remarque que tu te sens un peu moins bien. "
                  "Une petite pause pourrait te faire du bien ?";
        action = "suggestion";
        
      }
      
      return {
        'alertLevel': alertLevel,
        'consecutiveNegative': consecutiveNegative,
        'message': message,
        'action': action,
        'shouldShow': shouldShow,
        'totalMoods': moods.length,
      };
      
    } catch (e) {
      print('Erreur analyse émotions: $e');
      return {
        'alertLevel': 0,
        'consecutiveNegative': 0,
        'message': null,
        'shouldShow': false,
      };
    }
  }
  
  /// Récupère un exercice recommandé selon l'état émotionnel
  static Future<int?> getRecommendedExercise(int alertLevel) async {
    try {
      final tips = await SupabaseService.getTips();
      
      if (tips.isEmpty) return null;
      
      // Selon le niveau d'alerte, recommande différents types
      String preferredCategory = 'respiration'; // Par défaut
      
      if (alertLevel >= 3) {
        // Forte détresse → Respiration + Grounding
        preferredCategory = 'respiration';
      } else if (alertLevel == 2) {
        // Détresse modérée → Mental + Mouvement
        preferredCategory = 'mental';
      } else {
        // Détresse légère → Tout type
        preferredCategory = 'respiration';
      }
      
      // Trouve un tip de la catégorie préférée
      final recommendedTip = tips.firstWhere(
        (tip) => tip.category == preferredCategory,
        orElse: () => tips.first,
      );
      
      return recommendedTip.id;
      
    } catch (e) {
      print('Erreur recommandation exercice: $e');
      return null;
    }
  }
  
  /// Marque l'alerte comme vue (pour ne pas la re-afficher)
  static Future<void> dismissAlert() async {
    try {
      // Sauvegarder dans les préférences user que l'alerte a été vue
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await Supabase.instance.client
        .from('profiles')
        .update({
          'last_alert_dismissed': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
        
    } catch (e) {
      print('Erreur dismiss alert: $e');
    }
  }
  
  /// Vérifie si on doit afficher l'alerte (pas vue depuis 24h)
  static Future<bool> shouldShowAlert() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      
      final profile = await Supabase.instance.client
        .from('profiles')
        .select('last_alert_dismissed')
        .eq('id', userId)
        .single();
      
      final lastDismissed = profile['last_alert_dismissed'];
      
      if (lastDismissed == null) return true;
      
      final lastDismissedDate = DateTime.parse(lastDismissed);
      final now = DateTime.now();
      final difference = now.difference(lastDismissedDate);
      
      // Afficher si plus de 24h depuis le dernier dismiss
      return difference.inHours >= 24;
      
    } catch (e) {
      print('Erreur shouldShowAlert: $e');
      return true; // En cas d'erreur, on affiche quand même
    }
  }
}
